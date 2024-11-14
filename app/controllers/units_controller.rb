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
        header_style = sheet.styles.add_style(b: true, border: { style: :thin, color: '000000' })
        # Add the header row with bold and borders
        sheet.add_row ["Test", "Name", "Range", "Value"], style: [header_style] * 4
        @extracted_data.each do |values|
          test_description = values[:test]
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
  
  def combined_pdf
    @unit = Unit.find(params[:id])
  
    # Fetch first data (e.g., serial number, description, or info from text file)
    first_data = fetch_first_data(@unit)
  
    # Fetch second data (e.g., extract specific data from the text file)
    second_data = extract_data_from_text_file(@unit.text_file.download)  # Assuming you have text_file attached to the unit
  
    # Generate the PDF
    pdf = Prawn::Document.new
     # Add watermark image to all pages
    #image_path = "C:/Users/XWPVH61/Desktop/Dellent/Ruby Course/litepoint_ruby/litepoint/app/assets/images/ALTICE_LABS_LOGO_POS_HOR_TRANS_RGB.png"
    image_path = Rails.root.join('app', 'assets', 'images', 'ALTICE_LABS_LOGO_POS_HOR_TRANS_RGB.png').to_s
    #add_watermark_text(pdf, 'Property')
    add_watermark(pdf, image_path)

    pdf.text "Conducted Test Logfile", size: 18, style: :bold
    pdf.move_down 10
  
    # Add first data to PDF
    pdf.text "Unit Information:"
    pdf.text first_data
    pdf.move_down 20
  
    # Add second data as a table
    pdf.text "Test Data:", size: 14, style: :bold
    pdf.move_down 10
  
    # Prepare table data: header row and data rows
    table_data = [["Test", "Name", "Range", "Value"]]  # Table header row
  
    # Loop through the extracted second data and prepare rows for the table
    second_data.each do |data|
      if data[:name] == "TX Power" || data[:name] == "Freq. Error" || data[:name] == "Meas. Power" || data[:name] == "EVM"
        table_data << [
          data[:test] || "N/A",       # Test
          data[:name] || "Unknown",   # Name
          data[:range] || "N/A",      # Range
          data[:value].to_s || "0.0"  # Value (ensure it's a string)
        ]
      elsif data[:name] == "RX Power" || data[:name] == "PER"
        table_data << [
          data[:test] || "N/A",       # Test
          data[:name] || "Unknown",   # Name
          data[:range] || "N/A",      # Range
          data[:value].to_s || "0.0"  # Value (ensure it's a string)
        ]
      end
    end
  
    # Add the table to the PDF
    pdf.table(table_data, header: true, cell_style: { borders: [:top, :bottom, :left, :right], padding: 5, border_width: 0.5 }) do
      cells.style(align: :center)  # Center-align text in the cells
      row(0).style(background_color: 'DDDDDD')  # Highlight header row
    end
  
    # Send the generated PDF file to the browser
    send_data pdf.render, filename: "combined_info.pdf", type: "application/pdf", disposition: "inline"
  end
  
  def add_watermark_text(pdf, text)
    pdf.repeat(:all) do
      pdf.transparent(0.2) do
        pdf.rotate(25, origin: [pdf.bounds.width / 2, pdf.bounds.height / 2]) do
          pdf.text_box text, at: [pdf.bounds.width / 4, pdf.bounds.height / 2], size: 100, rotate: 45, style: :bold, color: 'AAAAAA'
        end
      end
    end
  end

  def add_watermark(pdf, image_path)
    pdf.repeat(:all) do
      pdf.transparent(0.4) do
        pdf.rotate(0, origin: [pdf.bounds.width / 2, pdf.bounds.height / 2]) do
          # Adjust the x and y coordinates to better center the image
          x_position = (pdf.bounds.width - 300) / 2  # Center horizontally
          y_position = ((pdf.bounds.height - 300) / 2) + 300 # Center vertically
  
          # Place the image at the adjusted position
          pdf.image image_path, at: [x_position, y_position], width: 300, height: 300
        end
      end
    end
  end

  def fetch_first_data(unit)
    # Example: Extract serial number and description
    serial_number = unit.serial_number
    description = unit.description
    "Serial Number: #{serial_number}\nDescription: #{description}"
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

    def add_tx_data(sheet, values)
      border_style = sheet.styles.add_style(border: { style: :thin, color: '000000' })
    
      sheet.add_row [values[:test], "TX_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "TX Power"
      sheet.add_row [values[:test], "MEASURED_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "Meas. Power"
      sheet.add_row [values[:test], "EVM", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "EVM"
      sheet.add_row [values[:test], "FREQ_ERROR_AVG", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "Freq. Error"
    end
    
    def add_rx_data(sheet, values)
      border_style = sheet.styles.add_style(border: { style: :thin, color: '000000' })
    
      sheet.add_row [values[:test], "RX_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "RX Power"
      sheet.add_row [values[:test], "PER", "0, #{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "PER"
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
      /^EVM_DB_AVG_S1\s*:\s*([-\d.]+)\s+dB\s+\(\s*,\s*(-?[\d.]+)\)/
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


