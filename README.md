# LoadTest
LoadTest written for Ruby 2.3

Single public method:

<name> -c x -n y http://url -d json_payload_for_post_request

parameters:

-c x  where x is the number of clients;

-n y where y the number of requests per client;

- url is the string value of the uri adress where http requests are made; 

-d <json> specifies the json payload to be used for POST requests;


OUTPUT:
check Apache Benchmark output
