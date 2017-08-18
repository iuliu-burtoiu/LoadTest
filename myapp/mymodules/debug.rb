module Debug
    def who_am_i?
        "#{self.class.name} (id: #{self.object_id}: #{self.name})" 
    end

    def print_me
        p "I'm getting printed #{self.class.name}"
    end

    class InsideDebug
        def who_am_i?
            "<#{self.class.name}>"
        end
    end
end