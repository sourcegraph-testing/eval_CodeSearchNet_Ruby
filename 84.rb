module Sp2db
  class BaseTable

    attr_accessor :name,
                  :sheet_name,
                  :worksheet,
                  :find_columns,
                  :spreadsheet_id,
                  :client

    def initialize opts={}

      if opts[:name].blank? && opts[:sheet_name].blank?
        raise "Must specify at least one of name or sheet name"
      end

      opts.each do |k, v|
        self.send "#{k}=", v
      end

      self.sheet_name ||= opts[:sheet_name] = config[:sheet_name] || worksheet.try(:title)
    end

    def active_record?
      false
    end

    # Table name
    def name
      @name ||= sheet_name.try(:to_sym) || raise("Name cannot be nil")
    end

    def spreadsheet_id
      @spreadsheet_id ||= config[:spreadsheet_id] || Sp2db.config.spreadsheet_id
    end

    def name=n
      @name = n&.to_sym
    end

    def find_columns
      @find_columns ||= config[:find_columns] || Sp2db.config.default_find_columns
    end

    def required_columns
      @required_columns ||= config[:required_columns] || []
    end

    def client
      @client = Sp2db.client
    end

    def spreadsheet
      client.spreadsheet spreadsheet_id
    end

    def sheet_name
      @sheet_name ||= (config[:sheet_name] || name)&.to_sym
    end

    def worksheet
      @worksheet = spreadsheet.worksheet_by_name(self.sheet_name.to_s)
    end

    def sp_data
      retries = 2
      begin
        raw_data = CSV.parse worksheet.export_as_string
      rescue Google::Apis::RateLimitError => e
        retries -= 1
        sleep(5)
        retry if retries >= 0
        raise e
      end

      data = process_data raw_data, source: :sp
      data
    end

    def csv_data
      raw_data = CSV.parse File.open(csv_file)
      data = process_data raw_data, source: :csv
      data
    end

    def header_row
      # @header_row ||= config[:header_row] || 0
      0
    end

    def csv_folder
      folder = "#{Sp2db.config.export_location}/csv"
      FileUtils.mkdir_p folder
      folder
    end

    def csv_file
      "#{csv_folder}/#{name}.csv"
    end

    def sp_to_csv opts={}
      write_csv to_csv(sp_data)
    end

    def write_csv data
      File.open csv_file, "wb" do |f|
        f.write data
      end
      csv_file
    end

    # Array of hash data to csv format
    def to_csv data
      attributes = data.first&.keys || []

      CSV.generate(headers: true) do |csv|
        csv << attributes

        data.each do |row|
          csv << attributes.map do |att|
            row[att]
          end
        end
      end
    end

    # Global config
    def config
      {}.with_indifferent_access
    end

    def process_data raw_data, opts={}
      raw_data = data_transform raw_data, opts unless opts[:skip_data_transform]
      raw_data = raw_filter raw_data, opts unless opts[:skip_data_filter]
      data = call_process_data raw_data, opts
      data
    end


    # Tranform data to standard csv format
    def data_transform raw_data, opts={}
      if config[:data_transform].present?
        config[:data_transform].call *args, &block
      else
        raw_data
      end
    end

    protected
    # Remove header which starts with "#"
    def valid_header? h
      h.present? && !h.match("^#.*")
    end

    # Header with "!" at the beginning or ending is required
    def require_header? h
      h.present? && (h.match("^!.*") || h.match(".*?!$"))
    end

    # Convert number string to number
    def standardize_cell_val v
      v = ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
      v = v.force_encoding("UTF-8") if v.is_a?(String)
      v
    end

    def call_process_data raw_data, opts={}
      data = raw_data
      if (data_proc = config[:process_data]).present?
        data = data_proc.call raw_data
      end
      data
    end

    # Remove uncessary columns and invalid rows from csv format data
    def raw_filter raw_data, opts={}
      raw_header = raw_data[header_row].map.with_index do |h, idx|
        is_valid = valid_header?(h)
        {
          idx: idx,
          is_remove: !is_valid,
          is_required: require_header?(h),
          name: is_valid && h.gsub(/\s*/, '').gsub(/!/, '').downcase
        }
      end

      rows = raw_data[(header_row + 1)..-1].map.with_index do |raw, rdx|
        row = {}.with_indifferent_access
        raw_header.each do |h|
          val = raw[h[:idx]]
          next if h[:is_remove]
          if h[:is_required] && val.blank?
            row = {}
            break
          end

          row[h[:name]] = standardize_cell_val val
        end

        next if row.values.all?(&:blank?)

        row[:id] = rdx + 1 if find_columns.include?(:id) && row[:id].blank?
        row
      end.compact
         .reject(&:blank?)
      rows = rows.select do |row|
        if required_columns.present?
          required_columns.all? {|col| row[col].present? }
        else
          true
        end
      end

      rows
    end

    class << self

      def all_tables
        ModelTable.all_tables + NonModelTable.all_tables
      end


      def table_by_names *names
        all_tables = self.all_tables
        if names.blank?
          all_tables
        else
          names.map do |n|
            all_tables.find {|tb| tb.name == n.to_sym} || raise("Not found: #{n}")
          end
        end
      end

      def sp_to_csv *table_names
        table_by_names(*table_names).map(&__method__)
      end

      def model_table_class
        ModelTable
      end

      delegate :sp_to_db, :csv_to_db, to: :model_table_class
    end
  end
end
