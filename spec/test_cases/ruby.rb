a = 'Banana'
b = "Toast #{a}"

b.split("").each do |moop|
    if moop == "a"
        puts "Lah lah"
    elsif moop == "o"
        puts 'Dawg.'
    end
end

def toast
    puts "Yarp"
rescue e
    puts "Narp"
end

begin
    puts "THIS"
end

toast
