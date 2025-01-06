module Takenoko
  class GoogleClient
    def initialize(cridential_file=nil)
      if cridential_file && ::File.exist?(cridential_file)
        @cridential = JSON.parse(File.read(cridential_file)).with_indifferent_access
      end
    end

    def get_table(table_name)
      table = Takenoko.table_config(table_name)
      raise "GoogleDrive: Sheet not found" unless sheet = session.spreadsheet_by_key(table['sheet_id'])

      if table[:worksheet_id].present?
        worksheet = sheet.worksheet_by_gid(table[:worksheet_id])
        table[:worksheet] = worksheet.title
      elsif table[:worksheet].present?
        raise "Worksheet #{table[:worksheet]} not found" unless worksheet = sheet.worksheet_by_title(table[:worksheet])
        table[:worksheet_id] = worksheet.gid.to_i
      elsif
        raise "You must specify worksheet or worksheet_id if mapping_file.yml"
      end

      update_table_config(table,worksheet.header)

      postprocess_class = if table[:enable_postprocess]
        begin
          Object.const_get(table[:postprocess_class])
        rescue NameError => e
          Rails.logger.warn e.message
          false
        end
      end

      Rails.logger.info "Getting table #{table_name}"
      rows = worksheet.populated_rows.map do |r|
        hash = HashWithIndifferentAccess.new
        table['columns_mapping'].each do |key,val|
          begin
            val = r.public_send(val)
          rescue Exception => e
            if key == 'id'
              val = r.row_num - 1
            else
              val = nil
            end
          end
          hash[key.to_sym] = format_row val
        end
        hash
      end

      if(postprocess_class)
        table[:rows] = rows.select do |row|
          if postprocess_class.respond_to? "spreadsheet_row_valid?"
            postprocess_class.public_send("spreadsheet_row_valid?",row)
          end
        end.map do |row|
          if postprocess_class.respond_to? "postprocess_spreadsheet_row"
            row = postprocess_class.public_send("postprocess_spreadsheet_row",row)
          end
          row
        end

        if postprocess_class.respond_to? "postprocess_spreadsheet_table"
          table = postprocess_class.public_send("postprocess_spreadsheet_table",table)
        end
      else
        table[:rows] = rows
      end

      return table
    end

    def session
      Rails.logger.info "Init session"
      unless @cridential
        return GoogleDrive.saved_session(Takenoko.personal_cridential_file)
      end

      key = OpenSSL::PKey::RSA.new(@cridential['private_key'])
      auth = Signet::OAuth2::Client.new(
        token_credential_uri: @cridential['token_uri'],
        audience: @cridential['token_uri'],
        scope: %w(
          https://www.googleapis.com/auth/drive
          https://spreadsheets.google.com/feeds/
        ),
        issuer: @cridential['client_email'],
        signing_key: key
      )

      auth.fetch_access_token!
      session = GoogleDrive.login_with_oauth(auth.access_token)
      return session
    end

    def spreadsheet(sheet_id=Takenoko.sheet_id)
      session.spreadsheet_by_key(sheet_id)
    end

    def folder_by_id(folder_id)
      session.collection_by_id(folder_id)
    end

    private
    def update_table_config(table,ws_header)
      columns_mapping = HashWithIndifferentAccess.new
      ws_header.select do |col|
        col.present? && ! col.match(/\s*#.*/)
      end.each do |col|
        if(table[:columns_mapping].present?)
          columns_mapping[col] = col && next unless table[:columns_mapping][col].present?
          next if table[:columns_mapping][col] == false
          columns_mapping[col] = table[:columns_mapping][col]
        else
          columns_mapping[col] = col
        end
      end

      table[:columns_mapping] = columns_mapping
      unless table[:columns_mapping].key?(table[:find_column])
          table[:columns_mapping][table[:find_column]] = table[:find_column]
      end

      table[:header] = table[:columns_mapping].keys
      return table
    end

    def format_row(v)
      return nil unless v
      ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
    end
  end
end