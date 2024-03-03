require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_number(phone_number)
  cleaned_number = phone_number.gsub(/\D/, '')

  return cleaned_number if cleaned_number.length == 10

  cleaned_number[1..] if cleaned_number.length == 11 && cleaned_number[0] == '1'
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def generate_letters(contents)
  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end

  contents.rewind
end

def retrieve_phone_numbers(contents)
  phone_numbers = []
  contents.each { |row| phone_numbers << clean_number(row[:homephone]) }

  contents.rewind

  phone_numbers.compact
end

def find_most_frequent_hour(contents)
  recurring_hours = {}
  recurring_hours.default = 0
  contents.each do |row|
    time = Time.strptime(row[:regdate], '%D %H')
    recurring_hours[time.hour.to_s] += 1
  end
  contents.rewind

  recurring_hours.max_by { |_hour, occurrence| occurrence }[0]
end

def find_most_frequent_day(contents)
  recurring_days = Hash.new(0)

  contents.each do |row|
    date = Time.strptime(row[:regdate], '%D %H')
    recurring_days[date.wday] += 1
  end
  contents.rewind

  day = recurring_days.max_by { |_day, occurrence| occurrence }[0]
  Date::DAYNAMES[day]
end

p retrieve_phone_numbers(contents)
puts "The most occuring hour is #{find_most_frequent_hour(contents)}."
puts "The most occuring day is #{find_most_frequent_day(contents)}"
