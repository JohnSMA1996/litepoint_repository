require 'axlsx'
class UnitsController < ApplicationController
  before_action :set_unit, only: [:show, :edit, :update, :destroy]

  # GET /units or /units.json
  def index
    @units = Unit.all
  end
  
  def search
    @units = Unit.where("serial_number LIKE ? OR description LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
  end

  def compare_units
    # Retrieve selected unit IDs from params
    selected_unit_ids = params[:selected_units]

    # Fetch the corresponding units
    @selected_units = Unit.where(id: selected_unit_ids)

    # Initialize a hash to store the data
    @combined_data = Hash.new { |hash, key| hash[key] = {} }

    @selected_units.each do |unit|
      if unit.text_file.attached?
        text_file_content = unit.text_file.download
        # Call your function to extract data for each unit
        data_for_unit = extract_data_from_text_file(text_file_content)
        
      else
        data_for_unit = []
      end

      #Delete end of list repeats
      data_for_unit = data_for_unit[0...-4]
      #Rails.logger.debug "Data for unit #{unit.id}: #{data_for_unit.inspect}"

      # Populate the combined_data hash
      data_for_unit.each do |data|
        key = "#{data[:test]}|#{data[:name]}|#{data[:range]}"
        #Rails.logger.debug "Storing value #{data[:value]} for key #{key} and unit #{unit.id}"
        @combined_data[key][unit.id] = data[:value]
      end

    end
    @combined_data 
    #Rails.logger.debug "Combined data: #{@combined_data.inspect}"
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

  #DELETE /units/1 or /units/1.json
  def destroy
    @unit.destroy

    respond_to do |format|
      format.html { redirect_to units_url, notice: "Unit was successfully destroyed." }
      format.json { head :no_content }
    end
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
    
  def extract_data_from_text_file(content)
    patterns = [
      /(.X_VERIFY|ANT\d|MCS\d+|\d{4}|BW-\d+)/,
      /^TX_POWER_DBM\s+: \s+([-\d.]+) dBm/,
      /^FREQ_ERROR_AVG\s+: \s+([-\d.]+) ppm\s+\(\s*(-?\d+,\s*-?\d+)\)/,
      /^POWER_DBM_RMS_AVG_S1\s+: \s+([-\d.]+) dBm\s+\(\s*(-?\d+,\s*-?\d+)\)/,
      /^EVM_DB_AVG_S1\s+: \s+([-\d.]+) dB\s+\(\s*(,\s*-?\d+)\)/
    ]

    patterns_rx = [
      /(.X_VERIFY|ANT\d|MCS\d+|\d{4}|BW-\d+)/,
      /^RX_POWER_DBM\s+: \s+([-\d.]+) dBm/,
      /^PER\s+: \s+([-\d.]+) %\s+\(\s*,?\s*(-?\d+)\s*\)/
    ]

    extracted_data = []
    split_test_content = content.split("[Info] Function completed.")
    split_test_content.each do |test_antenna|
      if test_antenna.include?("TX_VERIFY")
        test = test_antenna.scan(patterns[0]).flatten.first(5).join(' ')
        hash_key = test_antenna.scan(/^\d+/).first
        tx_power = test_antenna.scan(patterns[1]).flatten.first.to_f
        freq_error = test_antenna.scan(patterns[2]).flatten
        power_avg = test_antenna.scan(patterns[3]).flatten
        evm_avg = test_antenna.scan(patterns[4]).flatten
        extracted_data << { test: test, name: 'TX Power', value: tx_power, range: '(-)' }
        extracted_data << { test: test, name: 'Freq. Error', value: freq_error[0].to_f, range: "(#{freq_error[1]})" }
        extracted_data << { test: test, name: 'Meas. Power', value: power_avg[0].to_f, range: "(#{power_avg[1]})" }
        extracted_data << { test: test, name: 'EVM', value: evm_avg[0].to_f, range: "(#{evm_avg[1]})" }
      elsif test_antenna.include?("RX_VERIFY")
        hash_key = test_antenna.scan(/^\d+/)[0]
        test = test_antenna.scan(patterns_rx[0]).first(5).join(' ')
        rx_power = test_antenna.scan(patterns_rx[1]).flatten[0]
        per = test_antenna.scan(patterns_rx[2]).flatten
        extracted_data << { test: test, name: 'RX Power', value: rx_power, range: '(-)' }
        extracted_data << { test: test, name: 'PER', value: per[0], range: "(0,10%)" }
      end
    end
    extracted_data
  end

end


