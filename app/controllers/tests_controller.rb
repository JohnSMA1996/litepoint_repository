# app/controllers/tests_controller.rb
class TestsController < ApplicationController

	require 'open3'
	require 'net/ssh'
	require 'net/telnet'

	def index
		folder_contents('C:/LitePoint/IQfact_plus/IQfact+_BRCM_6726_Telnet_5.0.0.5_Lock/bin/scripts')
		@button_clicked = false
		#@results ||= { "mode" => "?", "wl0" => "?", "wl1" => "?", "wl2" => "?" }
		@results = flash[:results] || {
			mode: '?',
			wl0: '?',
			wl1: '?',
			wl2: '?'
		}
		Rails.logger.debug("Results in index: #{@results.inspect}")

	end

	def check_radios
		begin
			# Connect via Telnet
			telnet = Net::Telnet::new(
				'Host' => '192.168.1.1',
				'Timeout' => 10,
				'Prompt' => /[$%#>] \z/n
			)

			telnet.login('admin', 'admin') do |c|
				print c
			end

			telnet.cmd("sh") do |c|
				print c
			end

			output = ""
			telnet.cmd("wl -i wl0 -i wl1 -i wl2 ver") do |c|
				output << c
				print c
			end

			# Split the output into lines
			lines = output.split("\n")
			#p lines

			# Check for the presence of WLTEST in each wireless interface
			wl0test_present = lines.any? { |line| line.include?('wl0') && line.include?('WLTEST') }
			wl1test_present = lines.any? { |line| line.include?('wl1') && line.include?('WLTEST') }
			wl2test_present = lines.any? { |line| line.include?('wl2') && line.include?('WLTEST') }


			# Check for the presence of each wireless interface
			wl0_present = lines.any? { |line| line.include?('wl0') && line.include?('2G') }
			wl1_present = lines.any? { |line| line.include?('wl1') && line.include?('5G') }
			wl2_present = lines.any? { |line| line.include?('wl2') && line.include?('6G') }

			# Determine the test results
			@results = {
				mode: (wl0test_present && wl2test_present && wl2test_present) ? 'OK' : 'NOK',
				wl0: wl0_present ? 'OK' : 'NOK',
				wl1: wl1_present ? 'OK' : 'NOK',
				wl2: wl2_present ? 'OK' : 'NOK'
			}

			Rails.logger.debug("Results set: #{@results.inspect}")

			flash[:results] = @results
			telnet.close
		rescue => e
			Rails.logger.error("Telnet connection failed: #{e.message}")
			flash[:results] = {
				mode: 'NOK',
				wl0: 'NOK',
				wl1: 'NOK',
				wl2: 'NOK'
			}
		end
	
		# Redirect to index action
		redirect_to action: :index
	end
		


	private

	def folder_contents(path)
		unless File.directory?(path)
		render plain: "Invalid path", status: :bad_request
		return false
		end
		@files = Dir.entries(path).select { |f| File.file?(File.join(path, f)) }
	end
	
	def new_test
		folder_path = 'C:/LitePoint/IQfact_plus/IQfact+_BRCM_6726_Telnet_5.0.0.5_Lock/bin'
		@config_files = Dir.entries(folder_path)
				.select { |f| File.file?(File.join(folder_path, f)) && f.end_with?('.ini') }
		@pathloss_files = Dir.entries(folder_path)
		.select { |f| File.file?(File.join(folder_path, f)) && f.end_with?('.csv') } 
	end

	def create
		# Get the selected file from the form
		file = params[:file]

		# Run the test and get the result
		result = execute_test(file)

		# Assuming the result of the script is stored in a variable named result
		if result.successful?
		# Get the serial number and description for unit creation
		serial_number = params[:serial_number]
		description = params[:description]

		# Create a new unit based on the result
		@unit = Unit.new(serial_number: serial_number, description: description)
		@unit.text_file.attach(io: File.open('C:/LitePoint/IQfact_plus/IQfact+_BRCM_6726_Telnet_5.0.0.5_Lock/bin/Log/logOutput.txt'), filename: "#{serial_number}_log.txt")
		@unit.save

		redirect_to unit_path(@unit), notice: 'Test successful. Unit created.'
		else
		flash[:alert] = 'Test failed.'
		redirect_to tests_path
		end

	end

	def generate_file
		file_content = generate_file_logic()
  	end
	  
private

	def execute_test(file)
		puts "Running test..."
		result = OpenStruct.new(successful?: true)

		begin
			Dir.chdir('C:\\LitePoint\\IQfact_plus\\IQfact+_BRCM_6726_Telnet_5.0.0.5_Lock\\bin')
			command = "IQfactRun_Console.exe -run scripts/#{file}"
			command_thread = Thread.new do
			system(command)
			result.successful = true
			end
		rescue StandardError => e
			puts "Error during test execution: #{e.message}"
			result.successful = false
		end

		sleep(2)

		# Simulate pressing the "x" key
		shell = WIN32OLE.new("WScript.Shell")
		shell.SendKeys("x")

		puts "Test executed."
		result
	end

	def generate_file_logic()

@initialize_test = <<END
#LitePoint Test Flow Version 1.5.1 (2011-01-12)

RunMode = 0
RepeatTimes = 1
ExitWhenDone = 0
ShowFailInfo = 0
PrecisionDigitMode = 0
RetryMode = 0
EnableFlowCheckWarning = 0
WIFI_11BE:
	GLOBAL_SETTINGS
		#Input Parameters:
		>ANTENNA_COUNT [Integer]  = 8 
		>ANT1_PORT [String]  = RF1A 
		>ALWAYS_AGC [Integer]  = 0 
		>ANALYSIS_11AC_MASK_ACCORDING_CBW [Integer]  = 0 
		>ANALYSIS_11B_DC_REMOVE_FLAG [Integer]  = 0 
		>ANALYSIS_11B_EQ_TAPS [Integer]  = 1 
		>ANALYSIS_11B_FIXED_01_DATA_SEQUENCE [Integer]  = 0 
		>ANALYSIS_11B_METHOD_11B [Integer]  = 1 
		>ANALYSIS_AMPLITUDE_TRACKING [Integer]  = 0 
		>ANALYSIS_DECODE_PSDU [Integer]  = 0 
		>ANALYSIS_FREQUENCY_CORRELATION [Integer]  = 0 
		>ANALYSIS_FULL_PACKET_CHANNEL_EST [Integer]  = 0 
		>ANALYSIS_PHASE_CORR [Integer]  = 1 
		>ANALYSIS_PREAMBLE_AVERAGING [Integer]  = 0 
		>ANALYSIS_SYM_TIMING_CORR [Integer]  = 1 
		>AUTO_READING_LIMIT [Integer]  = 0 
		>CAPTURE_TIME_CW_US [Integer]  = 100 
		>CW_TEST_AVERAGE [Integer]  = 1 
		>DUT_KEEP_TRANSMIT [Integer]  = 0 
		>DUT_RX_SETTLE_TIME_MS [Integer]  = 0 
		>DUT_TX_SETTLE_TIME_MS [Integer]  = 0 
		>ENABLE_FAST_PER [Integer]  = 0 
		>EVM_AVERAGE [Integer]  = 3 
		>EVM_CAPTURE_TIME_11AC_VHT_US [Integer]  = 180 
		>EVM_CAPTURE_TIME_11AG_US [Integer]  = 95 
		>EVM_CAPTURE_TIME_11AX_HE_US [Integer]  = 400 
		>EVM_CAPTURE_TIME_11BE_EHT_US [Integer]  = 350 
		>EVM_CAPTURE_TIME_11B_L_US [Integer]  = 464 
		>EVM_CAPTURE_TIME_11B_S_US [Integer]  = 232 
		>EVM_CAPTURE_TIME_11N_GREENFIELD_US [Integer]  = 115 
		>EVM_CAPTURE_TIME_11N_MIXED_US [Integer]  = 123 
		>EVM_CAPTURE_TIME_CONTROL_PHY_US [Integer]  = 46 
		>EVM_CAPTURE_TIME_LPSC_PHY_US [Integer]  = 12 
		>EVM_CAPTURE_TIME_OFDM_PHY_US [Integer]  = 12 
		>EVM_CAPTURE_TIME_SC_PHY_US [Integer]  = 12 
		>EVM_PRE_TRIG_TIME_US [Integer]  = 3 
		>EVM_SYMBOL_NUM [Integer]  = 18 
		>IQ_P_TO_A_DSSS_CCK [Integer]  = 2 
		>IQ_P_TO_A_OFDM [Integer]  = 10 
		>LOAD_11AX_11BE_SU_WAVEFORM [Integer]  = 0 
		>LOAD_INTERNAL_WAVEFORM [Integer]  = 0 
		>LOAD_LEGACY_WAVEFORM [Integer]  = 1 
		>MASK_AVERAGE [Integer]  = 3 
		>MASK_SAMPLE_INTERVAL_US_CONTROL_PHY [Integer]  = 108 
		>MASK_SAMPLE_INTERVAL_US_LPSC_PHY [Integer]  = 40 
		>MASK_SAMPLE_INTERVAL_US_OFDM_PHY [Integer]  = 40 
		>MASK_SAMPLE_INTERVAL_US_SC_PHY [Integer]  = 40 
		>MASK_SMP_TM_DSSS_US [Integer]  = 286 
		>MASK_SMP_TM_OFDM_US [Integer]  = 95 
		>PER_FRAME_COUNT [Integer]  = 1000 
		>PER_VSG_TIMEOUT_SEC [Integer]  = 20 
		>PM_AVERAGE [Integer]  = 3 
		>PM_DSSS_SAMPLE_INTERVAL_US [Integer]  = 30 
		>PM_IF_FREQ_SHIFT_MHZ [Integer]  = 0 
		>PM_OFDM_SAMPLE_INTERVAL_US [Integer]  = 20 
		>PM_SAMPLE_INTERVAL_US_CONTROL_PHY [Integer]  = 46 
		>PM_SAMPLE_INTERVAL_US_LPSC_PHY [Integer]  = 12 
		>PM_SAMPLE_INTERVAL_US_OFDM_PHY [Integer]  = 12 
		>PM_SAMPLE_INTERVAL_US_SC_PHY [Integer]  = 12 
		>PM_TRIGGER_DSSS_US [Integer]  = 100 
		>PM_TRIGGER_OFDM_US [Integer]  = 20 
		>RELATIVE_LIMIT [Integer]  = 0 
		>RESET_TEST_ITEM_DURING_RETRY [Integer]  = 0 
		>RETRY_ERROR_ITEMS [Integer]  = 0 
		>RETRY_TEST_ITEM [Integer]  = 0 
		>SAVE_AUTOGENERATED_WAVEFORM_LOCAL [Integer]  = 0 
		>SKIP_PACKET_COUNT [Integer]  = 0 
		>SPECTRUM_SAMPLE_INTERVAL_US_OFDM_PHY [Integer]  = 12 
		>SPECTRUM_SMP_TM_DSSS_US [Integer]  = 286 
		>SPECTRUM_SMP_TM_OFDM_US [Integer]  = 95 
		>VDUT_TIMEOUT_MS [Integer]  = 0 
		>VSA_SAVE_CAPTURE_ALWAYS [Integer]  = 0 
		>VSA_SAVE_CAPTURE_ON_FAILED [Integer]  = 0 
		>VSA_TRIGGER_TIMEOUT_SEC [Integer]  = 17 
		>VSA_TRIGGER_TYPE [Integer]  = 6 
		>WAVEGEN_11AX_LAST_AMPDU_EOF_ON [Integer]  = 0 
		>CW_POWER_FILTER_BW [Double]  = 5.000000 
		>CW_SPEC_FFT_RBW [Double]  = 1.000000 
		>PACKET_DETECTION_GAP [Double]  = 1.000000 
		>PACKET_DETECTION_THRESHOLD [Double]  = 10.000000 
		>PER_WAVEFORM_PACKET_POST_GAP_HE_TB [Double]  = 30.000000 
		>PER_WAVEFORM_PACKET_POST_GAP_MU [Double]  = 30.000000 
		>PER_WAVEFORM_PACKET_POST_GAP_SU [Double]  = 30.000000 
		>PER_WAVEFORM_PACKET_POST_GAP_TFR [Double]  = 10.000000 
		>PM_PREAMBLE_START_US [Double]  = 4.000000 
		>PM_PREAMBLE_STOP_US [Double]  = 16.000000 
		>VSA_AMPLITUDE_TOLERANCE_DB [Double]  = 3.000000 
		>VSA_PRE_TRIGGER_TIME_US [Double]  = 3.000000 
		>VSA_TRIGGER_LEVEL_DB [Double]  = -25.000000 
		>VSG_MAX_POWER_11AC [Double]  = -5.000000 
		>VSG_MAX_POWER_11B [Double]  = 0.000000 
		>VSG_MAX_POWER_11G [Double]  = -5.000000 
		>VSG_MAX_POWER_11N [Double]  = -5.000000 
		>EVM_11N_HT20_REFERENCE_FILE_NAME_PREFIX [String]  = WiFi_HT20 
		>EVM_11N_HT40_REFERENCE_FILE_NAME_PREFIX [String]  = WiFi_HT40 
		>LOG_PATH [String]  = ./ 
		>PER_WAVEFORM_DESTINATION_MAC [String]  = 000000C0FFEE 
		>PER_WAVEFORM_PATH [String]  = ..\iqvsg 
		>PER_WAVEFORM_PREFIX [String]  =  
		>PER_WAVEFORM_SUFFIX [String]  =  
		>SPECTRUM_FLATNESS_LIMIT_2G [String]  =  
		>SPECTRUM_FLATNESS_LIMIT_5G [String]  =  
		>SPECTRUM_FLATNESS_LIMIT_6G [String]  =  
		#Return Values:
	CONNECT_IQ_TESTER
		#Input Parameters:
		>APP_ID [Integer]  = 1 
		>APT_ENABLE [Integer]  = 0 
		>DH_ENABLE [Integer]  = 0 
		>DH_OBTAIN_CONTROL_TIMEOUT_MS [Integer]  = 300000 
		>DH_PROBE_TIME_MS [Integer]  = 100 
		>DH_TOKEN_ID [Integer]  = 1 
		>IQTESTER_RECONNECT [Integer]  = 0 
		>IQTESTER_TYPE [Integer]  = 1 
		>REQUEST_RESOURCE_TIMEOUT_SEC [Integer]  = 30 
		>TEMP_COMP_THRESHOLD [Double]  = 0.000000 
		>IQTESTER_MODULE_01 [String]  = 192.168.100.254:A 
		>IQTESTER_MODULE_02 [String]  =  
		>IQTESTER_MODULE_03 [String]  =  
		>IQTESTER_MODULE_04 [String]  =  
		>IQTESTER_MODULE_05 [String]  =  
		>IQTESTER_MODULE_06 [String]  =  
		>IQTESTER_MODULE_07 [String]  =  
		>IQTESTER_MODULE_08 [String]  =  
		>OPTION_STRING [String]  =  
		#Return Values:
	INSERT_DUT
		#Input Parameters:
		>RELOAD_DUT_DLL [Integer]  = 1 
		>CONNECTION_STRING [String]  = 192.168.1.1 
		>DUT_DLL_FILENAME [String]  = BRCM6726_Telnet.dll 
		>EEPROM_FILENAME [String]  =  
		>OPTION_STRING [String]  = FC_WLAN_BRCM_General_TELNET_config.ini 
		#Return Values:
	INITIALIZE_DUT
		#Input Parameters:
		#Return Values:
	LOAD_PATH_LOSS_TABLE
		#Input Parameters:
		>RX_PATH_LOSS_FILE [String]  = PATHLOSS_7G_8ANT_12092023.csv 
		>TX_PATH_LOSS_FILE [String]  = PATHLOSS_7G_8ANT_12092023.csv 
		#Return Values:
END

@ending = <<END
REMOVE_DUT
#Input Parameters:
>OPTION_STRING [String]  =  
#Return Values:
DISCONNECT_IQ_TESTER
#Input Parameters:
#Return Values:
END

@rx_verify = <<END
RX_VERIFY
				#:display_color = 1
				#Input Parameters:
				>STANDARD [String]  = 802.11be 
				>TEST_CATEGORY [String]  = STA_RX_DL_SU 
				>MEASUREMENTS [String]  = PER 
				>DATA_RATE [String]  = MCS0 
				>PACKET_FORMAT [String]  = EHT_MU 
				>BSS_BANDWIDTH [String]  = BW-20 
				>CH_BANDWIDTH [String]  = 0 
				>BSS_FREQ_MHZ_PRIMARY [Integer]  = 2412 
				>CH_FREQ_MHZ [Integer]  = 2412 
				>NUM_STREAMS [Integer]  = 1 
				>ANT1 [Integer]  = 0
				>ANT2 [Integer]  = 0 
				>ANT3 [Integer]  = 0 
				>ANT4 [Integer]  = 0 
				>ANT5 [Integer]  = 0 
				>ANT6 [Integer]  = 0 
				>ANT7 [Integer]  = 0 
				>ANT8 [Integer]  = 0 
				>ARRAY_HANDLING_METHOD [Integer]  = 3 
				>CODING_TYPE [String]  = LDPC 
				>MPDU_MAX_LENGTH [Integer]  = 10000 
				>RX_POWER_DBM [Double]  = -92 
				>CABLE_LOSS_DB1 [Double]  = 0 
				>CABLE_LOSS_DB2 [Double]  = 0 
				>CABLE_LOSS_DB3 [Double]  = 0 
				>CABLE_LOSS_DB4 [Double]  = 0 
				>CABLE_LOSS_DB5 [Double]  = 0 
				>CABLE_LOSS_DB6 [Double]  = 0 
				>CABLE_LOSS_DB7 [Double]  = 0 
				>CABLE_LOSS_DB8 [Double]  = 0 
				>BSS_COLOR [Integer]  = 1 
				>BSS_FREQ_MHZ_SECONDARY [Integer]  = 0 
				>CH_FREQ_MHZ_PRIMARY_20MHz [Integer]  = 0 
				>DCM [Integer]  = 0 
				>FRAME_COUNT [Integer]  = 0 
				>GI_LTF_TYPE [Integer]  = 1 
				>MAC_ADDRESS [String]  =  
				>NUM_HE_LTF [Integer]  = 1 
				>OPTION_STRING [String]  =  
				>PACKET_EXTENSION [Double]  = 1.6e-005 
				>PSDU_LENGTH [Integer]  = 0 
				>RU_SIZE [Integer]  = 1 
				>SPATIAL_MAPPING_MATRIX [String]  =  
				>STA_ID [String]  =  
				>STBC [Integer]  = 0 
				>WAVEFORM_NAME [String]  =  
				>EHT_PUNC_MODE [String]  = 0-No puncturing 
				>EHT_SIG_MCS [Integer]  = 0 
				>PREAMBLE [String]  = SHORT 
				>GUARD_INTERVAL [String]  = LONG 
				#Return Values:
				<PER [Double]  = <, 10>
END
	
@tx_verify = <<END
TX_VERIFY
			#:display_color = 1
			#Input Parameters:
			>STANDARD [String]  = 802.11be 
			>TEST_CATEGORY [String]  = AP_TX_DL_SU 
			>MEASUREMENTS [String]  = E,M,P,S 
			>DATA_RATE [String]  = MCS13 
			>PACKET_FORMAT [String]  = EHT_MU 
			>BSS_BANDWIDTH [String]  = BW-20 
			>CH_BANDWIDTH [String]  = 0 
			>BSS_FREQ_MHZ_PRIMARY [Integer]  = 2422 
			>CH_FREQ_MHZ [Integer]  = 2422 
			>NUM_STREAMS [Integer]  = 1 
			>ANT1 [Integer]  = 0 
			>ANT2 [Integer]  = 0 
			>ANT3 [Integer]  = 0 
			>ANT4 [Integer]  = 0 
			>ANT5 [Integer]  = 0 
			>ANT6 [Integer]  = 0 
			>ANT7 [Integer]  = 0 
			>ANT8 [Integer]  = 0 
			>EVM_LIMIT [Double]  = 0 
			>ARRAY_HANDLING_METHOD [Integer]  = 3 
			>CODING_TYPE [String]  = LDPC 
			>TX_POWER_DBM [Double]  = 19 
			>CABLE_LOSS_DB1 [Double]  = 0 
			>CABLE_LOSS_DB2 [Double]  = 0 
			>CABLE_LOSS_DB3 [Double]  = 0 
			>CABLE_LOSS_DB4 [Double]  = 0 
			>CABLE_LOSS_DB5 [Double]  = 0 
			>CABLE_LOSS_DB6 [Double]  = 0 
			>CABLE_LOSS_DB7 [Double]  = 0 
			>CABLE_LOSS_DB8 [Double]  = 0 
			>BSS_COLOR [Integer]  = 1 
			>BSS_FREQ_MHZ_SECONDARY [Integer]  = 0 
			>CH_FREQ_MHZ_PRIMARY_20MHz [Integer]  = 0 
			>DCM [Integer]  = 0 
			>EHT_SIG_MCS [Integer]  = 0 
			>GI_LTF_TYPE [Integer]  = 1 
			>NUM_HE_LTF [Integer]  = 1 
			>PSDU_LENGTH [Integer]  = 1000 
			>RU_SIZE [Integer]  = 1 
			>STBC [Integer]  = 0 
			>USE_ALL_SIGNAL [Integer]  = 1 
			>OBW_PERCENTAGE [Double]  = 99 
			>PACKET_EXTENSION [Double]  = 1.6e-005 
			>SAMPLING_TIME_US [Double]  = 0 
			>EHT_PUNC_MODE [String]  = 0-No puncturing 
			>MAC_ADDRESS [String]  =  
			>OPTION_STRING [String]  =  
			>STA_ID [String]  =  
			#Return Values:
			<FREQ_ERROR_AVG [Double]  = < -10, 10>
			<POWER_DBM_RMS_AVG_S1 [Double]  = < 17, 21>
			<EVM_DB_AVG_S1 [Double]  = <, -38>
END

		@file_path = "C:/LitePoint/IQfact_plus/IQfact+_BRCM_6726_Telnet_5.0.0.5_Lock/bin/scripts/#{params[:test_name]}.txt"

		@initialize_test["192.168.1.1"] = params[:ip]
		@initialize_test["FC_WLAN_BRCM_General_TELNET_config.ini"] = params[:config_file]
		@initialize_test["PATHLOSS_7G_8ANT_12092023.csv"] = params[:path_loss_file]

		File.open(@file_path, "w") { |file| file.puts "Configuração Teste Litepoint" }
		File.open(@file_path, "w") do |file|  # Use "w" instead of "a" to overwrite the file
			file.write(@initialize_test)  # Write the string to the file
		end

		def process_params(verify, mcs, bands, param_prefix, freq_prefix, power_prefix)
			verify.gsub!(/(>DATA_RATE \[String\]  = MCS).*/, "\\1#{mcs}")
		  
			bands&.each do |band|
			  param_bw = :"#{band}_#{param_prefix}"
			  params[param_bw]&.each do |bw|
				verify.gsub!(/(>BSS_BANDWIDTH \[String\]  = BW-).*/, "\\1#{bw}")
		  
				param_freq = :"#{freq_prefix}_#{band}_#{bw}"
		  
				params[param_freq]&.each do |freq|
				  param_power = :"#{power_prefix}_#{band}_#{bw}"
				  #verify.gsub!(/(>#{power_prefix.upcase}_DBM \[Double\]  = )\d+/, "\\1#{params[param_power]}")
				  verify.gsub!(/(>#{power_prefix.upcase}_DBM \[Double\]  = )-?\d+/) { "#{$1}#{params[param_power]}" }

				  if power_prefix.upcase == 'TX_POWER'
					power_interval = [params[param_power].to_i - 2, params[param_power].to_i + 2]
					verify.gsub!(/(<POWER_DBM_RMS_AVG_S1 \[Double\]  = ).*/, "\\1< #{power_interval[0]}, #{power_interval[1]}>")
				  end
		  
				  verify.gsub!(/(>BSS_FREQ_MHZ_PRIMARY \[Integer\]  = ).*/, "\\1#{freq}")
				  verify.gsub!(/(>CH_FREQ_MHZ \[Integer\]  = ).*/, "\\1#{freq}")
		  
				  (1..4).each do |i|
					verify.gsub!(/(>ANT#{i} \[Integer\]  = ).*/, "\\11")
					File.open(@file_path, "a") { |file| file.write(verify) }
					verify.gsub!(/(>ANT#{i} \[Integer\]  = ).*/, "\\10")
				  end
				end
			  end
			end
		  end
		  
		  
		  process_params(@tx_verify, params[:mcs_tx], params[:bands], 'bw_tx', 'tx_frequencies', 'tx_power')
		  process_params(@rx_verify, params[:mcs_rx], params[:bands_rx], 'bw_rx', 'rx_frequencies', 'rx_power')
		  
		File.open(@file_path, "a") { |file| file.write(@ending) }
	end
end
  