# Parse emails from their full format into a hash containing full email, host,
# local token, and the raw argument.
#
# Some Body <somebody@example.com>
# # => {
#   token: 'somebody',
#   host: 'example.com',
#   email: 'somebody@example.com',
#   full: 'Some Body <somebody@example.com>',
# }
require 'mail'

module Griddler::EmailParser
  def self.parse_address(full_address)
    email_address = extract_email_address(full_address)
    name = extract_name(full_address)
    token, host = split_address(email_address)
    {
      token: token,
      host: host,
      email: email_address,
      full: full_address,
      name: name,
    }
  end

  def self.extract_reply_body(body)
    if body.blank?
      ""
    else
      remove_reply_portion(body)
        .to_s.split(/[\r]*\n/)
        .reject do |line|
          line =~ /^[[:space:]]+>/ ||
            line =~ /^[[:space:]]*Sent from my /
        end.
        join("\n").to_s.strip
    end
  end

  def self.extract_headers(raw_headers)
    if raw_headers.is_a?(Hash)
      raw_headers
    else
      header_fields = Mail::Header.new(raw_headers).fields

      header_fields.inject({}) do |header_hash, header_field|
        header_hash[header_field.name.to_s] = header_field.value.to_s
        header_hash
      end
    end
  end

  private

  def self.reply_delimeter_regex
    delimiter = Array(Griddler.configuration.reply_delimiter).join('|')
    %r{#{delimiter}}
  end

  def self.extract_email_address(full_address)
    full_address.to_s.split('<').last.to_s.delete('>').to_s.strip
  end

  def self.extract_name(full_address)
    full_address = full_address.to_s.strip
    name = full_address.to_s.split('<').first.to_s.strip
    if name.present? && name != full_address
      name
    end
  end

  def self.split_address(email_address)
    email_address.try :split, '@'
  end

  def self.regex_split_points
    [
      reply_delimeter_regex,
      /^[[:space:]]*[-]+[[:space:]]*Original Message[[:space:]]*[-]+[[:space:]]*$/i,
      /^[[:space:]]*--[[:space:]]*$/,
      /^[[:space:]]*\>?[[:space:]]*On.*\r?\n?.*wrote:\r?\n?$/,
      /On.*wrote:/,
      /\*?From:.*$/i,
      /^[[:space:]]*\d{4}\/\d{1,2}\/\d{1,2}[[:space:]].*[[:space:]]<.*>?$/i
    ]
  end

  def self.remove_reply_portion(body)
    regex_split_points.inject(body) do |result, split_point|
      result.to_s.split(split_point).first || ""
    end
  end
end
