require 'axlsx'
class UnitsController < ApplicationController
  before_action :set_unit, only: [:show, :edit, :update, :destroy]

  # GET /units or /units.json
  def index
    @units = Unit.all
  end
  
  def download
    @unit = Unit.find(params[:id])
  
    if @unit.text_file.attached?
      send_data @unit.text_file.download, filename: "#{@unit.serial_number}.txt"
    else
      flash[:error] = 'Text file not found.'
      redirect_to unit_path(@unit)
    end
  end

  def download_excel
    @unit = Unit.find(params[:id])
  
    if @unit.text_file.attached?
      text_file_content = @unit.text_file.download
      @extracted_data = extract_data_from_text_file(text_file_content)
  
      xlsx_package = Axlsx::Package.new
      wb = xlsx_package.workbook
  
      # Add a worksheet
      wb.add_worksheet(name: "Unit Data") do |sheet|
        # Add data to the worksheet
        sheet.add_row ["Test", "Name", "Range", "Value"] # Header row
  
        @extracted_data.each do |key, values|
          test_description = values[0]
          test_type = test_description.include?("TX_VERIFY") ? "TX" : "RX"
  
          case test_type
          when "TX"
            add_tx_data(sheet, values)
          when "RX"
            add_rx_data(sheet, values)
          end
        end
      end
  
      send_data xlsx_package.to_stream.read, filename: "#{@unit.serial_number}.xlsx"
    else
      flash[:error] = 'Text file not found.'
      redirect_to unit_path(@unit)
    end
  end
  
  def show
    @unit = Unit.find(params[:id])

    if @unit.text_file.attached?
      text_file_content = @unit.text_file.download
      @extracted_data = extract_data_from_text_file(text_file_content)
    else
      @extracted_data = {}
    end
  end
  
  # GET /units/new
  def new
    @unit = Unit.new
  end

  # GET /units/1/edit
  def edit
  end

  # POST /units or /units.json
  def create
    @unit = Unit.new(unit_params)

    respond_to do |format|
      if @unit.save
        format.html { redirect_to unit_url(@unit), notice: "Unit was successfully created." }
        format.json { render :show, status: :created, location: @unit }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /units/1 or /units/1.json
  def update
    respond_to do |format|
      if @unit.update(unit_params)
        format.html { redirect_to unit_url(@unit), notice: "Unit was successfully updated." }
        format.json { render :show, status: :ok, location: @unit }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /units/1 or /units/1.json
  # def destroy
  #   @unit.destroy

  #   respond_to do |format|
  #     format.html { redirect_to units_url, notice: "Unit was successfully destroyed." }
  #     format.json { head :no_content }
  #   end
  # end

  def destroy
    @unit = Unit.find(params[:id])
    @unit.destroy
  
    redirect_to units_path, notice: 'Unit was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_unit
      @unit = Unit.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def unit_params
      params.require(:unit).permit(:serial_number, :description, :file, :text_file)
      #params.require(:unit).permit(:serial_number, :description, files: [])
    end
  
    def add_tx_data(sheet, values)
      sheet.add_row [values[0], "TX_POWER", "", values[1]] if values.size > 1
      sheet.add_row [values[0], "MEASURED_POWER", "(#{values[2][1]})", values[2][0]] if values.size > 2
      sheet.add_row [values[0], "EVM", "(#{values[3][1]})", values[3][0]] if values.size > 3
      sheet.add_row [values[0], "FREQ_ERROR_AVG", "(#{values[4][1]})", values[4][0]] if values.size > 4
    end
    
    def add_rx_data(sheet, values)
      sheet.add_row [values[0], "RX_POWER", "", values[1]] if values.size > 1
      sheet.add_row [values[0], "PER", "(0, #{values[2][1]})", values[2][0]] if values.size > 2
    end

    def extract_data_from_text_file(content)
      patterns = [
        /(.X_VERIFY|ANT\d|MCS\d+|\d{4}|BW-\d+)/,
        /^TX_POWER_DBM\s+: \s+([-\d.]+) dBm/,
        /^FREQ_ERROR_AVG\s+: \s+([-\d.]+) ppm\s+\(\s+(-?\d+,\s*-?\d+)\)/,
        /^POWER_DBM_RMS_AVG_S1\s+: \s+([-\d.]+) dBm\s+\(\s*(-?\d+,\s*-?\d+)\)/,
        /^EVM_DB_AVG_S1\s+: \s+([-\d.]+) dB\s+\(\s*(,\s*-?\d+)\)/,
      ]

      patterns_rx = [
        /(.X_VERIFY|ANT\d|MCS\d+|\d{4}|BW-\d+)/,
        /^RX_POWER_DBM\s+: \s+([-\d.]+) dBm/,
        /^PER\s+: \s+([-\d.]+) %\s+\(\s*,?\s*(-?\d+)\s*\)/
      ]
    
      extracted_data = {}
      split_test_content = content.split("[Info] Function completed.")
      split_test_content.each do |test_antenna|
        # Filters undesired blocks of information
        if test_antenna.include?("TX_VERIFY")
          test = test_antenna.scan(patterns[0]).first(5).join(' ')
          hash_key = test_antenna.scan(/^\d+/)[0]
          tx_power = test_antenna.scan(patterns[1])[1].to_a[0].to_f
          freq_error = test_antenna.scan(patterns[2])[0]
          power_avg = test_antenna.scan(patterns[3]).flatten
          evm_avg = test_antenna.scan(patterns[4])[0]
          extracted_data[hash_key] = [test, tx_power, power_avg, evm_avg, freq_error]
        elsif test_antenna.include?("RX_VERIFY")
          hash_key = test_antenna.scan(/^\d+/)[0]
          test = test_antenna.scan(patterns_rx[0]).first(5).join(' ')
          rx_power = test_antenna.scan(patterns_rx[1]).flatten[0]
          per = test_antenna.scan(patterns_rx[2]).flatten
          extracted_data[hash_key] = [test, rx_power,per]
        end
      end
      extracted_data.delete(extracted_data.keys.last) if extracted_data.keys.length > 1
      #puts extracted_data
      extracted_data
    end

end


