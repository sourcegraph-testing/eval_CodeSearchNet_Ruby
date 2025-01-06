#encoding: utf-8

gem 'myerror'
require_relative 'vector.class'

module EpiMath
# TODO : improve the documentation
class Matrix
  attr_reader :columns, :lines, :v

  # Convert each element of an Array in an Integer => must be implented in Array Class
  def self.to_inttab arg, num=Float
    Error.call "Matrix::to_inttab : '#{arg}' is not a valid Array", Error::ERR_HIGH if !arg.is_a?Array

    arg.size.times do |i|
      # if it's an Array in an Array, the
      if arg[i].is_a?Array
        arg[i] = self.to_inttab argv[i]

      else
        if num == Integer
          arg[i] = arg[i].to_i
        else
          arg[i] = arg[i].to_f
        end
      end

    end
  end

  # == Parameters:
  # tab::
  #   tab is a double Array like [ [1,2], [3,4], [1,4] ]. This array should be a valid Matrix tab or an other Matrix
  #
  # == Returns:
  #   nothing
  def initialize tab=[[]]
    @v = tab #Must call to_inttab
    @columns = 0
    @lines = 0

    if tab.is_a?Array and tab.size > 0 and tab[0].is_a?Array
      @columns = tab[0].size

      # check if the line have the good size
      tab.size.times do |i|
        @lines += 1
        if (tab[i].size != @columns)
          Error.call "Matrix::new : '#{tab[i]}' is not a valid line"
        end

      end
    elsif tab.is_a?Matrix
      @v = tab.v
      @columns = tab.columns
      @lines = tab.lines
    else
      Error.call "Matrix::new : '#{tab}' is not a valid matrix"
    end
    return
  end

  def to_s
    out = ""

    @v.each do |line|
      out << "["

      # display all elements of this line
      line.each do |element|
        out << element.to_f.round(3).to_s << " "
      end

      out << "\b]\n" # TODO : FIX THAT broggi_t
    end
    out
  end

  def to_ary
    @v
  end

  def to_vector
    return Vector.new self.get_val(0, 0), self.get_val(1, 0)
  end

  def new_line tab=[]
    Error.call "Matrix::new_line : Size of the new line (#{tab} => #{tab.size}) is not valid" if !tab.is_a?Array or tab.size != @column

    @lines += 1
    @v << tab
  end

  def new_column tab=[]
    Error.call "Matrix::new_column : Size of the new column (#{tab} => #{tab.size}) is not valid" if !tab.is_a?Array or tab.size != @lines

    @columns += 1
    if tab.is_a? Array and tab.size == @lines
      @lines.times do |i|
        @v[i] << tab[i]
      end
    else
      @lines.times do |i|
        @v[i] << 0
      end
    end
  end

  def del_line x=-1
    if x.is_a?Integer and @v[x] != nil
       @lines -= 1
       @v.delete_at x
    else
       Error.call "Matrix::del_line : Line '#{x}' doesn't exist"
    end
  end

  # == Parameters:
  # x,y::
  #   Integers. They are the coordonates of the value which will extract from the matrix
  # == Returns:
  # a value fo the matrix
  def get_val x, y
    if !x.is_a?Integer
      Error.call "Matrix::get_val : '#{x}' is not a correct line"
      return nil
    elsif !y.is_a?Integer
      Error.call "Matrix::get_val : '#{y}' is not a correct column"
      return nil
    elsif x < 0 or y < 0 or x >= @lines or y >= @columns
      Error.call "Matrix::get_val : The specified positions are invalids (#{x},#{y})"
      return nil
    else
      return @v[x][y]
    end
  end

  # == Parameters:
  # x,y::
  #   Integers. They are the coordonates of the value which will write in the matrix
  # == Returns:
  # a value fo the matrix
  def set_val val, x, y
    if !x.is_a?Integer
      Error.call "Matrix::set_val : '#{x}' is not a correct line"
      return nil
    elsif !y.is_a?Integer
      Error.call "Matrix::set_val : '#{y}' is not a correct column"
      return nil
    elsif !val.is_a?Numeric
      Error.call "Matrix::set_val : '#{val}' is not a correct value"
      return nil
    elsif x < 0 or y < 0 or x >= @lines or y >= @columns
      Error.call "Matrix::set_val : The specified positions are invalids (#{x} >= #{@lines},#{y} >= #{@columns})\n#{self.to_s}"
      return nil
    else
      @v[x][y] = val
      return @v[x][y]
    end
  end

  # == Parameters:
  # y::
  #   Integer. It's the n° line which is extracted
  # == Returns:
  # Array
  def get_line x
    Error.call "Matrix::get_line : Line #{x} doesn't exist" if !x.is_a?Integer or x < 0 or x >= @lines

    return @v[x]
  end

  # == Parameters:
  # y::
  #   Integer. It's the n° column which is extracted
  # == Returns:
  # Array
  def get_column y
    Error.call "Matrix::get_column : Column #{y} doesn't exist" if !y.is_a?Integer or y < 0 or y >= @columns

    result = []
    @lines.times do |i|
      result << @v[i][y]
    end
    return result
  end

  # == Params:
  # matrix::
  #   matrix is a Matrix to compare.
  # == Returns:
  # True or False.
  # == Usage::
  # The function check if the current matrix and matrix:: have the same dimensions (linse and columns)
  def have_the_same_dimensions matrix
    if (matrix.is_a?Matrix and matrix.columns == @columns and matrix.lines == @lines)
      true
    else
      false
    end
  end

  # == Parameters:
  # t1,t2::
  #   Multiply each elements of t1 and t2 2b2 and sum all
  # == Returns:
  # Float
  def self.mult_array(t1, t2)
    Error.call "Can't multiply this. One of the arguments is not an array.", Error::ERR_HIGH if (!t1.is_a?Array or !t2.is_a?Array)
    Error.call "Can't multiply this. Arrays do not have the same size.", Error::ERR_HIGH if t1.size != t2.size

    result = 0.0
    t1.size.times do |i|
      result = (result + t1[i].to_f * t2[i].to_f).to_f
    end
    return result
  end

  # == Parameters:
  # matrix::
  #   This argument is a Matrix or an Integer.
  #   If it's a Matrix, it will do matrix product.
  #   Else, if it's a integer, it will multiply each coeficient of the current Matrix.
  #
  # == Returns:
  # Matrix
  #
  # == Matrix_Product:
  # little explanation::
  #   If matrix is a Matrix, we will multiply 2by2 each coeficient of the column X of the current Matrix and the line X of matrix.
  #   Then, we do the sum of them and we put it in a new Matrix at the position X. The is just a sum up, view the details on wiki bitch.
  def *(matrix)
    #produit matriciel
    #convert vector -> matrix
    if matrix.is_a?Vector
      Error.call "Matrix::* : Transformation implicite de Vector en Matrix", Error::ERR_LOW
      matrix = matrix.to_matrix
    end

    if matrix.is_a?Matrix
      Error.call "Matrix::* : Invalid multiplication at line #{matrix.lines} and column #{@columns}", Error::ERR_HIGH if @columns != matrix.lines

      result = []
      @lines.times do |i|
        result << []
      end
      #colonne de resultat = colonne de matrix X
      #ligne de resutlat = ligne de self Y
      @lines.times do |y|
        matrix.columns.times do |x|
          result[y][x] = Matrix.mult_array(get_line(y), matrix.get_column(x))
        end
      end

      return Matrix.new result
    #produit d'un entier et d'une matrix
    elsif matrix.is_a?Numeric
      result = @v
      @lines.times do |x|
        @columns.times do |y|
          result[x][y] = result[x][y].to_f * matrix
        end
      end
    return Matrix.new result
    #message d'erreur
    else
      Error.call "Matrix::* : Impossible de calculer cela (#{matrix} n'est pas une matrix)", Error::ERR_HIGH
    end
  end

  # == Parameters:
  # matrix::
  #   This argument is a Matrix or an Integer. If it's a Matrix, it must have the same dimensions than the current Matrix.
  #   Else, if it's a integer, it will be added to each coeficients of the current Matrix.
  #
  # == Returns:
  # Matrix
  def +(matrix)
    result = @v
    if have_the_same_dimensions matrix
      @lines.times do |x|
        @columns.times do |y|
          result[x][y] += matrix.v[x][y]
        end
      end
    elsif matrix.is_a?Numeric
      @lines.times do |x|
        @columns.times do |y|
          result[x][y] += matrix
        end
      end
    else
      Error.call "Matrix::+ : Impossible de calculer cela", Error::ERR_HIGH
    end
    Matrix.new result
  end

  # == Returns::
  #   Numerical value which is the determinant of the matrix. It only work on 2x2
  def get_deter
    Error.call "Matrix::get_deter : This error comes from get_deter which works only with 2x2 matrix" if @columns != 2 or @lines != 2

    det = get_val(0, 0).to_i * get_val(1, 1).to_i
    det -= get_val(0, 1).to_i * get_val(1, 0).to_i
    return det
  end

end
end
