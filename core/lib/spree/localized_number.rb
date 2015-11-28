module Spree
  class LocalizedNumber
    # Given a string, strips all non-price-like characters from it,
    # taking into account locale settings. Returns the input given anything
    # else.
    #
    # @param number [String, anything] the number to be parsed or anything else
    # @return [BigDecimal, anything] the number parsed from the string passed
    #   in, or whatever you passed in
    def self.parse(number)
      return number unless number.is_a?(String)

      separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
      non_number_characters = /[^0-9\-#{separator}]/

      # work on a copy, prevent original argument modification
      number = number.dup
      # strip everything else first
      number.gsub!(non_number_characters, '')
      # then replace the locale-specific decimal separator with the standard separator if necessary
      number.gsub!(separator, '.') unless separator == '.'

      number.to_d
    end
  end
end
