module AttrLogger

    def attr_logger (name)

        attr_reader name

        define_method("#{name}=") do |val|
            puts "Assigning #{val.inspect} to #{name}"
            instance_variable_set("@#{name}", val)
        end
    end

end