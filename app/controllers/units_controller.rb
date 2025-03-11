require 'axlsx'
include ApplicationHelper
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

  def download_comparison_excel
    # Use the same logic to retrieve selected units and combined data
    selected_unit_ids = params[:selected_units]
    @selected_units = Unit.where(id: selected_unit_ids)
    @combined_data = Hash.new { |hash, key| hash[key] = {} }
  
    @selected_units.each do |unit|
      if unit.text_file.attached?
        text_file_content = unit.text_file.download
        data_for_unit = extract_data_from_text_file(text_file_content)
      else
        data_for_unit = []
      end
  
      # Remove end-of-list repeats
      data_for_unit = data_for_unit[0...-4]
  
      # Populate combined_data
      data_for_unit.each do |data|
        key = "#{data[:test]}|#{data[:name]}|#{data[:range]}"
        @combined_data[key][unit.id] = data[:value]
      end
    end
  
    # Generate the Excel file
    xlsx_package = Axlsx::Package.new
    wb = xlsx_package.workbook
  
    # Add a worksheet
    wb.add_worksheet(name: "Comparison Results") do |sheet|
      # Add headers
      headers = ["Test", "Name", "Range"]
      @selected_units.each do |unit|
        headers << unit.serial_number
      end
      header_style = sheet.styles.add_style(b: true, border: { style: :thin, color: '000000' })
      sheet.add_row headers, style: [header_style] * headers.size
  
      # Add data rows
      @combined_data.each do |key, values|
        test, name, range = key.split('|', 3)
        row = [test, name, range]
        row_styles = [nil, nil, nil]

        @selected_units.each do |unit|
          value = values[unit.id] || ""
          row << value
          value_class = calculate_value_class(value, range, name)
          row_styles << sheet.styles.add_style(bg_color: value_class_to_color(value_class), border: { style: :thin, color: '000000' })
        end

        sheet.add_row row, style: row_styles
      end
    end
  
    # Send the file to the user
    send_data xlsx_package.to_stream.read,
              filename: "comparison_results.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def download_comparison_pdf
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
  
      # Remove end-of-list repeats
      data_for_unit = data_for_unit[0...-4]
  
      # Populate the combined_data hash
      data_for_unit.each do |data|
        key = "#{data[:test]}|#{data[:name]}|#{data[:range]}"
        @combined_data[key][unit.id] = data[:value]
      end
    end
  
    # Create a PDF document
    pdf = Prawn::Document.new
    image_path = Rails.root.join('app', 'assets', 'images', 'ALTICE_LABS_LOGO_POS_HOR_TRANS_RGB.png').to_s
    add_watermark(pdf, image_path)
  
    pdf.text "Comparison of Units", size: 18, style: :bold, align: :center
    pdf.move_down 20
  
    # Add table headers
    table_data = [["Test", "Name", "Range"] + @selected_units.map(&:serial_number)]
  
    # Add table rows
    @combined_data.each do |key, values|
      test, name, range = key.split('|', 3)
      row = [test, name, range]
      @selected_units.each do |unit|
        value = values[unit.id] || "N/A"
        value_class = calculate_value_class(value, range, name)
        value_color = value_class_to_color(value_class)
        row << { content: value.to_s, background_color: value_color }
      end
      table_data << row
    end
  
    # Add table to PDF
    pdf.table(table_data, header: true, cell_style: { borders: [:top, :bottom, :left, :right], padding: 5, border_width: 0.5 }) do
      cells.style(align: :center)
      row(0).style(background_color: 'AAAAAA', text_color: 'FFFFFF', size: 12, font_style: :bold)
    end
  
    # Send the PDF to the browser
    send_data pdf.render, filename: "comparison_results.pdf", type: "application/pdf", disposition: "inline"
  end 

  def value_class_to_color(value_class)
    case value_class
    when 'table-success'
      '90EE90' # Light Green
    when 'table-danger'
      'FF6347' # Tomato Red
    else
      'FFFFFF' # Default White
    end
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
          # Apply styles based on value class
          value_class = calculate_value_class(values[:value], values[:range], values[:name])
          value_style = sheet.styles.add_style(bg_color: value_class_to_color(value_class), border: { style: :thin, color: '000000' })
          sheet.rows.last.cells[3].style = value_style
        end
      end
  
      send_data xlsx_package.to_stream.read, filename: "#{@unit.serial_number}.xlsx"
    else
      flash[:error] = 'Text file not found.'
      redirect_to unit_path(@unit)
    end
  end

  def download_excel_file2
    @unit = Unit.find(params[:id])
  
    if @unit.second_text_file.attached?
      text_file_content = @unit.second_text_file.download
      @extracted_data = extract_data_from_2text_file(text_file_content)
  
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
          test_type = test_description.include?("TX_") ? "TX" : "RX"
  
          case test_type
            #add_iot_tx_data
          when "TX"
            add_tx_iot_data(sheet, values)
          when "RX"
            add_rx_iot_data(sheet, values)
          end
          # Apply styles based on value class
          value_class = calculate_value_class(values[:value], values[:range], values[:name])
          value_style = sheet.styles.add_style(bg_color: value_class_to_color(value_class), border: { style: :thin, color: '000000' })
          sheet.rows.last.cells[3].style = value_style
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
  
    # Loop through the data to process the values and add colors
    second_data.each do |data|
      value_class = calculate_value_class(data[:value], data[:range], data[:name])
      value_color = value_class_to_color(value_class)

      # Add the row with the appropriate background color
      table_data << [
        data[:test] || "N/A",       # Test
        data[:name] || "Unknown",   # Name
        data[:range] || "N/A",      # Range
        { content: data[:value].to_s || "0.0", background_color: value_color }  # Value (ensure it's a string)
      ]
    end
  
    # Add the table to the PDF
    pdf.table(table_data, header: true, cell_style: { borders: [:top, :bottom, :left, :right], padding: 5, border_width: 0.5 }) do
      cells.style(align: :center)  # Center-align text in the cells
      row(0).style(background_color: 'DDDDDD')  # Highlight header row
    end
  
    # Send the generated PDF file to the browser
    send_data pdf.render, filename: "combined_info.pdf", type: "application/pdf", disposition: "inline"
  end

  def combined_pdf2
    @unit = Unit.find(params[:id])

    # Fetch first data
    first_data = fetch_first_data(@unit)

    # Fetch second data
    second_data = extract_data_from_2text_file(@unit.second_text_file.download)

    # Generate the PDF
    pdf = Prawn::Document.new

    # Add watermark
    image_path = Rails.root.join('app', 'assets', 'images', 'ALTICE_LABS_LOGO_POS_HOR_TRANS_RGB.png').to_s
    add_watermark(pdf, image_path)

    # Add content to the PDF
    pdf.text "Conducted Test Logfile", size: 18, style: :bold
    pdf.move_down 10

    # Add first data
    pdf.text "Unit Information:"
    pdf.text first_data
    pdf.move_down 20

    # Add table header
    pdf.text "Test Data:", size: 14, style: :bold
    pdf.move_down 10

    table_data = [["Test", "Name", "Range", "Value"]]  # Header row

    # Loop through the data to process the values and add colors
    second_data.each do |data|
      value_class = calculate_value_class(data[:value], data[:range], data[:name])
      value_color = value_class_to_color(value_class)

      # Add the row with the appropriate background color
      case data[:name]
      when "TX Power"
        table_data << [
          data[:test], 
          "TX_POWER", 
          "#{data[:range]}", 
          { content: data[:value].to_s, background_color: value_color }
        ]
      when "Meas. Power"
        table_data << [
          data[:test], 
          "MEASURED_POWER", 
          "#{data[:range]}", 
          { content: data[:value].to_s, background_color: value_color }
        ]
      when "EVM"
        table_data << [
          data[:test], 
          "EVM", 
          "#{data[:range]}", 
          { content: data[:value].to_s, background_color: value_color }
        ]
      when "Freq. Error"
        table_data << [
          data[:test], 
          "FREQ_ERROR", 
          "#{data[:range]}", 
          { content: data[:value].to_s, background_color: value_color }
        ]
      else
        table_data << [
          data[:test], 
          data[:name], 
          "#{data[:range]}", 
          { content: data[:value].to_s, background_color: value_color }
        ]
      end
    end
    # Add table to PDF
    pdf.table(table_data, header: true, cell_style: { borders: [:top, :bottom, :left, :right], padding: 5, border_width: 0.5 }) do
      cells.style(align: :center)  # Center-align text in the cells
      row(0).style(background_color: 'DDDDDD')  # Highlight header row
    end
    
    # Send the PDF to the browser
    send_data pdf.render, filename: "unit_test_logfile.pdf", type: "application/pdf", disposition: "inline"
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

    # Handle second text file
    if @unit.second_text_file.attached?
      second_file_content = @unit.second_text_file.download
      @extracted_data_second_file = extract_data_from_2text_file(second_file_content)
    else
      @extracted_data_second_file = {}
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

    def add_tx_iot_data(sheet, values)
      border_style = sheet.styles.add_style(border: { style: :thin, color: '000000' })

      # Handle specific TX parameter cases
      case values[:name]
      when "TX Power"
        sheet.add_row [values[:test], "TX_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4
      when "Meas. Power"
        sheet.add_row [values[:test], "MEASURED_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4
      when "EVM"
        sheet.add_row [values[:test], "EVM", "#{values[:range]}", values[:value]], style: [border_style] * 4
      when "Freq. Error"
        sheet.add_row [values[:test], "FREQ_ERROR_AVG", "#{values[:range]}", values[:value]], style: [border_style] * 4
      when /^ACP Max Power Offset/
        # Handle ACP Max Power Offset entries dynamically
        sheet.add_row [values[:test], values[:name].upcase.tr(" ", "_"), "#{values[:range]}", values[:value]], style: [border_style] * 4
      else
        # Handle other TX parameters like Fn_MAX or Delta_F
        sheet.add_row [values[:test], values[:name].upcase, "#{values[:range]}", values[:value]], style: [border_style] * 4
      end
    end

    def add_rx_iot_data(sheet, values)
      border_style = sheet.styles.add_style(border: { style: :thin, color: '000000' })
    
      sheet.add_row [values[:test], "RX_POWER", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "RX Power"
      sheet.add_row [values[:test], "PER", "#{values[:range]}", values[:value]], style: [border_style] * 4 if values[:name] == "PER"
    end
    
    # Only allow a list of trusted parameters through.
    def unit_params
      params.require(:unit).permit(:serial_number, :description, :file, :text_file, :second_text_file)
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
        extracted_data << { test: test, name: 'EVM', value: evm_avg[0].to_f, range: "(,#{evm_avg[1]})" }
      elsif test_antenna.include?("RX_VERIFY")
        hash_key = test_antenna.scan(/^\d+/)[0]
        test = test_antenna.scan(patterns_rx[0]).first(5).join(' ')
        rx_power = test_antenna.scan(patterns_rx[1]).flatten[0]
        per = test_antenna.scan(patterns_rx[2]).flatten
        extracted_data << { test: test, name: 'RX Power', value: rx_power, range: '(-)' }
        extracted_data << { test: test, name: 'PER', value: per[0], range: "(0,10)%" }
      end
    end
    extracted_data
  end

  def extract_data_from_2text_file(content)
    # Updated patterns based on new data (TX and RX sections)
    patterns_zigbee = [
      # Test name
      /(TX_LE\s+\d+\s\w{3,6})|(TX_MULTI_VERIFICATION\s+\d+)/,
      # Extract TX Power (EXPECTED_TX_POWER_DBM, e.g., -90 dBm)
      /^EXPECTED_TX_POWER_DBM\s*:\s*([-\d.]+)\s+dBm/,
      # Extract Power Average (POWER_AVERAGE_DBM, e.g., 19.26 dBm (18.2, 20))
      /^POWER_AVERAGE\w{0,4}\s+:\s+([-\d.]+) dBm\s+\(\s*(-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?)/,
      # Extract EVM (Error Vector Magnitude, e.g., 1.28 dB (0.85, 1.56))
      /^EVM_OFFSET_ALL\s+:\s+(-\d.+)dB\s+\(,\s*(-?\d+(\.\d+)?)\)/,
      # Extract Freq Error (FREQ_ERROR_AVG_PPM, e.g., 6.00 ppm (-30, 30))
      /^FREQ_ERROR_AVG_PPM\w{0,4}\s+:\s+([-\d.]+) ppm\s+\(\s*(-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?)\)/
    ]

    patterns_ble = [
      # Test name
      /(TX_LE\s+\d+\s\w{3,6})|(TX_MULTI_VERIFICATION\s+\d+)/,
      # Extract TX Power (EXPECTED_TX_POWER_DBM, e.g., -90 dBm)
      /^EXPECTED_TX_POWER_DBM\s*:\s*([-\d.]+)\s+dBm/,
      # Extract Power Average (POWER_AVERAGE_DBM, e.g., 19.26 dBm (18.2, 20))
      /^POWER_AVERAGE\w{0,4}\s+:\s+([-\d.]+) dBm\s+\(\s*(-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?)/,
      /^Fn_MAX\s+:\s+([-\d.]+) kHz\s+\(\s*(-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?)/,
      /^INITIAL_FREQ_OFFSET\s+:\s+([-\d.]+) kHz\s+\(\s*(-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?)/,
      #/^ACP_MAX_POWER_DBM_OFFSET_(-?\d+)\s+:\s*([-\d.]+)\s+dBm\s+\(\s*,\s*(-?\d+)\s*\)$/
      /(?m-ix:^ACP_MAX_POWER_DBM_OFFSET_(-?\d+)\s+:\s*([-\d.]+)\s+dBm\s+\(\s*,\s*(-?\d+)\s*\)$)/,
      /(DELTA_F\d+_\w+|\w+_MAX(?:_AT_\d{1,2}_99_9)?)\s+:\s+([\d\.]+)\s+kHz\s*\(\s*(\d*\.?\d+)?\s*,?\s*(\d*\.?\d+)?\s*\)/
    ]
  
    patterns_rx = [
      # Extract RX_LE (RX_LE, e.g., 2402 1LE)
      /(RX_LE\s+\d+\s.+LE)|(RX_VERIFY_PER\s+\d+)/,
      # Extract RX Power (RX_POWER_LEVEL, e.g., -90 dBm)
      /^RX_POWER_LEVEL\s*:\s*([-\d.]+)\s+dBm/,
      # Extract PER (Packet Error Rate, e.g., 0.00 % (0, 10))
      /^PER\s+: \s+([-\d.]+) %\s+\(\s*,?\s*(-?\d+)\s*\)/
    ]
    #return [] if file_content.nil? || file_content.empty?
    extracted_data = []
    split_test_content = content.split("[Info] Function completed.")
    if split_test_content.length > 7
    split_test_content[7...-1].each do |test_antenna|
    #split_test_content.each do |test_antenna|
      # Handle Zigbee TX-related data extraction
      if test_antenna.include?("TX_MULTI_VERIFICATION")
        # Extract test name from the first line (using the first 5 words)
        test = test_antenna.scan(patterns_zigbee[0]).flatten.first(5).join(' ')
  
        # Extract TX Power, Frequency Error, Measured Power, and EVM values using the updated patterns
        tx_power = test_antenna.scan(patterns_zigbee[1]).flatten.first.to_f
        power_avg = test_antenna.scan(patterns_zigbee[2]).flatten
        evm = test_antenna.scan(patterns_zigbee[3]).flatten
        freq_error = test_antenna.scan(patterns_zigbee[4]).flatten
        
        # Add extracted TX data to extracted_data array
        extracted_data << { test: test, name: 'TX Power', value: tx_power, range: '(-)' }
        extracted_data << { test: test, name: 'Meas. Power', value: power_avg[0].to_f, range: "(#{power_avg[1]})" }
        extracted_data << { test: test, name: 'EVM', value: evm[0].to_f, range: "(,#{evm[1]})" }
        extracted_data << { test: test, name: 'Freq. Error', value: freq_error[0].to_f, range: "(#{freq_error[1]})" }
        
      elsif test_antenna.include?("TX_LE")
        # Extract test name from the first line (using the first 5 words)
        test = test_antenna.scan(patterns_ble[0]).flatten.first(5).join(' ')

        # Extract TX Power, Frequency Error, Measured Power, and EVM values using the updated patterns
        tx_power = test_antenna.scan(patterns_ble[1]).flatten.first.to_f
        power_avg = test_antenna.scan(patterns_ble[2]).flatten
        fn_max = test_antenna.scan(patterns_ble[3]).flatten
        init_freq_off = test_antenna.scan(patterns_ble[4]).flatten
        test_antenna = test_antenna.gsub("\r\n", "\n").strip
        acp_max_powers = test_antenna.scan(patterns_ble[5])
        delta_f = test_antenna.scan(patterns_ble[6])
        #puts delta_f

        # Add extracted TX data to extracted_data array
        extracted_data << { test: test, name: 'TX Power', value: tx_power, range: '(-)' }
        extracted_data << { test: test, name: 'Meas. Power', value: power_avg[0].to_f, range: "(#{power_avg[1]})" }
        extracted_data << { test: test, name: 'Fn_MAX', value: fn_max[0].to_f, range: "(#{fn_max[1]})" }
        extracted_data << { test: test, name: 'Initial Freq. Offset', value: init_freq_off[0].to_f, range: "(#{init_freq_off[1]})" }
        acp_max_powers.each do |match|
          offset, value, range = match # Destructure the match into variables 
          extracted_data << {
            test: test,
            name: "ACP Max Power Offset #{offset}",
            value: value.to_f,
            range: "(,#{range})"
          }
        end
        # Loop through each match and process the data
        delta_f.each do |match|
          name, value, range_start, range_end = match  # Destructure the match
          # Prepare the range formatting
          # Ignore ranges with no values (e.g., "(,)")
          next if range_start.nil? && range_end.nil?
          # Format range based on captured values
          range = "(#{range_start},#{range_end})"
          # Store the result in extracted_data
          extracted_data << {
            test: test,  # Replace with actual test name
            name: name,
            value: value.to_f,  # Ensure the value is a float
            range: range
          }
        end
      # Handle RX-related data extraction
      elsif test_antenna.include?("RX_LE") || test_antenna.include?("RX_VERIFY_PER")
        # Extract test name (using the first 5 words from the line)
        test = test_antenna.scan(patterns_rx[0]).join('')
        
        # Extract RX Power and Packet Error Rate (PER)
        rx_power = test_antenna.scan(patterns_rx[1]).flatten.first.to_f
        per = test_antenna.scan(patterns_rx[2]).flatten
  
        # Add extracted RX data to extracted_data array
        extracted_data << { test: test, name: 'RX Power', value: rx_power, range: '(-)' }
        extracted_data << { test: test, name: 'PER', value: per[0], range: "(0, 10)%" }
      else
        next
      end
    end
    else
      Rails.logger.warn("Not enough elements in split_test_content to process. Length: #{split_test_content.length}")
    end
  
    extracted_data
  end
  


end


