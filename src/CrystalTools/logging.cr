module CrystalTools

  macro log(msg,level=1)
    msg1 = {{msg}}
    #expand to 16
    ffrom = {{ @type.stringify }}.downcase()[0,16].ljust(16)
    msg = " - #{ffrom} : #{msg1}" 
    {% if level == 1 %}
    puts msg.colorize(:green)
    {% elsif level == 2 %}
    puts msg.colorize(:yellow)
    {% else %}
    puts msg.colorize(:light_gray)
    {% end %}
    
  end

  macro error(msg,extra="")
    puts {{msg}}.colorize(:red)
    {% if extra %}
    puts {{extra}}
    {% end %}
    raise {{msg}}
    exit 1
  end    

end

