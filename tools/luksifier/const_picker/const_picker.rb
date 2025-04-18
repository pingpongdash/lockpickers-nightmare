# Ruby version of const_picker for only pi
require 'optparse'
require 'base64'
require 'bigdecimal'
require 'bigdecimal/math'
include BigMath

# --- Helper Functions ---
def encode_block(block, fmt)
  case fmt
  when 'raw'
    block
  when 'hex'
    block.unpack1('H*')
  when 'base64'
    Base64.encode64(block).strip
  else
    raise "Unsupported format: #{fmt}"
  end
end

# --- Argument Parsing ---
options = {
  count: 1,
  format: 'raw'
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby const_picker_pi.rb [options]'

  opts.on('-sSTART', '--start=START', 'Start digit offset (supports 0x/0o/0b)') do |v|
    options[:start] = Integer(v)
  end
  opts.on('-lLENGTH', '--length=LENGTH', 'Length of block') do |v|
    options[:length] = Integer(v)
  end
  opts.on('-C', '--count=COUNT', Integer, 'Number of blocks') do |v|
    options[:count] = v
  end
  opts.on('-fFORMAT', '--format=FORMAT', 'Output format (raw, hex, base64)') do |v|
    options[:format] = v
  end
  opts.on('-v', '--verbose', 'Verbose output') do
    options[:verbose] = true
  end
end.parse!

# --- Constants & Precision Setup ---
raise 'Start and length are required' unless options[:start] && options[:length]
total_digits = options[:start] + options[:length] * options[:count] + 10

BigDecimal.limit(total_digits)
pi_str = BigMath::PI(total_digits).to_s('F').split('.')[1]  # Get fractional part

# --- Extraction ---
options[:count].times do |i|
  offset = options[:start] + i * options[:length]
  block = pi_str[offset, options[:length]]
  encoded = encode_block(block, options[:format])

  if options[:verbose]
    puts "[#{i}] pi at offset #{offset} (0x#{offset.to_s(16).upcase}), length #{options[:length]} (0x#{options[:length].to_s(16).upcase})"
  end
  puts encoded
end
