module ApplicationHelper
  def calculate_value_class(value, range, name)
    # Handle cases where the range is nil or not applicable
    return 'table-default' if range.nil? || range == "(-)" || range.empty?
  
    # Match the range pattern
    range_match = range.match(/\(\s*(?<low>-?\d*\.?\d*)\s*,?\s*(?<high>-?\d*\.?\d*)\s*\)/)
  
    # Debugging: Log range and match details
    #Rails.logger.debug("Value: #{value}, Range: #{range}, Range Match: #{range_match}")
  
    # Handle invalid ranges
    return 'table-default' if range_match.nil?
  
    # Extract low and high bounds
    low = range_match[:low].present? ? range_match[:low].to_f : nil
    high = range_match[:high].present? ? range_match[:high].to_f : nil
  
    # Debugging: Log extracted bounds
    #Rails.logger.debug("Parsed Range for #{name}: Low=#{low}, High=#{high}")
  
    # Determine class based on value and range
    if (low.nil? || value.to_f >= low) && (high.nil? || value.to_f <= high)
      'table-success' # Green for within range
    else
      'table-danger'  # Red for out of range
    end
  end
  
  
  
end
