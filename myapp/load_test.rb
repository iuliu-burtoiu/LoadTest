require "./myapp/mymodules/ibu_exceptions.rb"
require "thwait"
require "socket"
require "uri/generic"
require "optparse"
require 'httpclient'

class LoadTest

    #CONSTANTS
    LOG_FILE_PATH = "/myapp/LoadTest.txt"
    LOG_STRING_BUILDER = StringIO.new

    #CONSTRUCTOR
    def initialize(concurency_level, total_requests_count, url, json_payload = "")
        @concurency_level = concurency_level if validate_parameter("concurency_level", concurency_level, Integer)
        @total_requests_count = total_requests_count if validate_parameter("total_requests_count",total_requests_count, Integer)
        @url = url if validate_parameter("url", url, String)
        @json_payload = json_payload

        @label_maxlength = 0 # used in the formatting process

        @log_hash = {}
    end

    attr_reader :concurency_level, :total_requests_count, :url, :json_payload

    public
        def run
             puts "", "<BEGIN TEST>"
             global_start_time = Time.now
             r_per_clevel = (Float(@total_requests_count) / @concurency_level).floor
             threads = []

             is_server_responsive, server_response, server_hostname = server_getinfo()

            log %<Server Software:  #{server_response}>
            log %<Server Hostname:  #{server_hostname}>
            log %<Server Port:  80> # all calls are http or https.
            log %<Http Method:  #{(json_payload.nil? ? "GET" : "POST")}>

             @concurency_level.times do |tIndex|
                threads << Thread.new(url, json_payload, tIndex) do|u,j,i|
                    start_time = Time.now
                    results =[]
                    client = HTTPClient.new
                    #add the remaining requests if concurency and request do not divide exactly
                    r_per_clevel = r_per_clevel+ @total_requests_count % @concurency_level if i== @concurency_level-1
                    r_per_clevel.times do |level_iteration|
                        results << request_do(client, u, start_time,j)
                    end

                    results
                end
            end if is_server_responsive

            # ThreadsWait.all_waits(*threads)
            thread_results = []
            threads.each do|t|
                t.value.each {|tr| thread_results << tr}
            end
           
            log %<\nConcurency level:  #{concurency_level}>
            log %<Time taken for tests:  #{total_time  = (Time.now.to_f - global_start_time.to_f).round(3)} seconds>

            success_count, fail_count, html_transferred, average_request_time = analyse_result(thread_results)

            log %<Complete requests:  #{success_count}>
            log %<Failed requests:  #{fail_count}>
            log %<HTML transferred:  #{html_transferred} bytes>

            # thread_results.each.with_index {|r, index| p %<#{index}:  #{r.success}, #{r.delta}>}
            
            log %<Requests per second:  #{(Float(thread_results.length) / total_time.ceil).round(3) } [#/sec] (mean)>
            log %<Time per request:  #{average_request_time.round(3)} [ms] (mean)>
            log %<Transfer rate:  #{(html_transferred / (1000 *total_time.ceil)).round(3)}[Kbytes/sec] received>

            log %<\nDocument Path:  #{LOG_FILE_PATH}>
            log %<Document Length:  #{Float(LOG_STRING_BUILDER.size)/1000} kbytes>
           
            log_write(LOG_STRING_BUILDER)
            puts "<END TEST>", ""
        end
        # STATIC version
        def self.run
            catch(:exit) do 
                start()
            end

         puts "exit now..."
        end

    private
        # returns both success and fail counts, and also total transferred bytes, averate request time
        def analyse_result(thread_results)
            success_count, failed_count  = 0, 0
            html_transferred = total_request_time = 0.0
            thread_results.each do|tr|
                if(tr.success)
                    success_count += 1
                else
                    failed_count += 1
                end
                
                html_transferred += tr.htmlSize
                total_request_time += tr.delta
            end

            return success_count, failed_count, html_transferred, total_request_time / thread_results.length
        end
        # writes into the StringIO instance
        def log(strValue)
            label_length = strValue =~/:/
            @label_maxlength = label_length unless @label_maxlength > label_length
            LOG_STRING_BUILDER.puts strValue
        end
        # writes down the IO content
        def log_write(stringIO)
            linesArr = format(stringIO)
            file = nil
            begin 
                #always recreate file
                File.delete(LOG_FILE_PATH) if File.exists?(LOG_FILE_PATH)
                file = File.new(LOG_FILE_PATH, "w")
                #stringIO.rewind
                linesArr.each do |sline|
                    file.write sline
                    p sline 
                end
            rescue RuntimeError => r_err
                p %<Failed to log data due to error #{r_err}>
            else #triggered always in case of success
                # reinitialize for a new session
                stringIO.reopen("")
            ensure
                file.close() unless file.nil?
            end
        end
        def format(stringIO)
           additional_indentation = 4
           formatedLines = []
           
           stringIO.rewind # need to move cursor to begining
           stringIO.each do |line|
                current_label_length = line =~/:/
                next if current_label_length.nil?

                leading_spaces = []
                (@label_maxlength + additional_indentation - current_label_length).times {leading_spaces << " "}

                line.sub!(/:/, ":" + leading_spaces.join)
                formatedLines << line
           end

           formatedLines
        end
        # performes a GET web request
        def request_do(http_client, url, s_time, json_data)
            success = false
            result = Struct.new(:success, :delta, :htmlSize)
            delta_time = 0
            begin
                http_response = json_data.nil? ? http_client.get(url) 
                                               : http_client.post(url, json_data)
                success = true
            rescue ArgumentError => a_ex
                p %<Argument is wrong here: #{a_ex.inspect}>
                raise
            rescue SocketError => s_ex
                p %<Unknown url host : #{s_ex.inspect}>
                raise
            rescue StandardError => u_ex
                p %<Unknown Exception here: #{u_ex.inspect}\n>
                raise
            # else
            #     puts %<Success on #{Thread.current.object_id}>
             ensure
                delta_time = Time.now - s_time
                result = result.new(success, delta_time, http_response.body.size)
            end

            result
        end
        # returns bool, server description string
        def server_getinfo
            result,client,host  = nil
            serverline_rgx = /Server: /
            success = false

            begin
                client = TCPSocket.open(host = URI(@url).host,80)
                client.send("OPTIONS / HTTP/1.0\r\nHost: #{host}\r\n\r\n", 0) # 0 means standard packet
                client.readlines.each do |line|
                    result =  line.sub(serverline_rgx, "") if line =~ serverline_rgx
                    break unless result.nil?
                end
                success = true
            rescue StandardError => s_err
                p "Failed to get server #{s_err}"
                result = "Unknown service"
                host = "Unknown host"
            ensure 
                client.close() unless client.nil?
            end

            return success,result,host
        end
        # validates the parameter and raises LoadTestException, StandardError or returns true
        def validate_parameter(param_name = "", param_value, kind_of_param)

            raise %<Invalid type "#{param_value.class}" for parameter "#{param_name}". It should be #{kind_of_param}> unless param_value.kind_of? kind_of_param

            case param_value
                when Integer
                    raise Ibu::Exceptions::LoadTestException, %<Invalid "#{param_name}" integer>, caller unless param_value > 0
                when String
                    raise Ibu::Exceptions::LoadTestException, "Invalid uri: #{param_value}", caller unless param_value =~/https?:\/\/\w+\.\w{,3}/
                # else
                #     raise Ibu_Exceptions::LoadTestException, "Invalid type for parameter #{param_name}", caller 
            end
            
            true
        end
        # initializes console input procedure for getting & parsing user commands [and parameters].
        def self.start
            puts "ENTER COMMAND", ""
            input = gets.chomp.split
            options = {:concurency=>1, :number=>1} # default values
            parser = OptionParser.new do |opts|
                        opts.banner = "Usage: run [options]"
                        # opts.on("run") do
                        #   options[:command] ="run"
                        #   puts ">>COMMAND"
                        # end
                        # opts.on(" ") do |u|
                        #  options[:uri] = u
                        # end
                        opts.on("-c", "-concurency [Integer]", Integer, "# of concurrent http clients triggering parallel requests.") do |c|
                            options[:concurency] = c
                        end
                        opts.on("-n", "-number_of_requests [Integer]", Integer, "# of total requests") do |n|
                            options[:number] = n
                        end
                        opts.on("-d", "-json", String, "Json payload for POST requests") do |j|
                            options[:json] = j
                        end
                    end
            rest = parser.parse(input) # must allways contain 2 values
            options[:command] = rest[0]
            options[:uri] = rest[1]

            begin
                case options[:command] 
                    when "run"
                        LoadTest.new( options[:concurency],options[:number],options[:uri], options[:json])
                                .run()
                    when "exit"
                        throw :exit
                    else   
                        puts "WRONG COMMAND: #{options[:command]}"
                end
            rescue Ibu::Exceptions::LoadTestException => lte
                puts "Invalid command parameters. Try again"
                puts lte.message
            end

            LoadTest.start()
        end
end

# automatically launch test upon loading the .rb file.
p LoadTest.run