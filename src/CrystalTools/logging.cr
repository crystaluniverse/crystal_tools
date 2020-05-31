module CrystalTools
  macro log(msg, level = 1)
    msg1 = {{msg}}
    #expand to 25
    ffrom = {{ @type.stringify }}.downcase()[0,25].ljust(25)
    msg2 = " - #{ffrom} : #{msg1}" 
    {% if level == 1 %}
    puts msg2.colorize(:green)
    {% elsif level == 2 %}
    puts msg2.colorize(:yellow)
    {% elsif level == 3 %}
    puts msg2.colorize(:red)
    {% else %}
    puts msg2.colorize(:light_gray)
    {% end %}
    
  end

  macro error(msg, extra = "")
    puts {{msg}}.colorize(:red)
    {% if extra %}
    puts {{extra}}
    {% end %}
    raise {{msg}}
    exit 1
  end
end
