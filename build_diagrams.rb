#! /usr/bin/ruby

# this file builts all svg's from the various diagrams
# so they can be used in github

require 'net/http'
require 'json'

kroki_url = ENV["KROKI_URL"] || "https://kroki.io";
if (!kroki_url.start_with?("http")) then
    exit(1);
end

$uri = URI.parse(kroki_url);
if (!["http","https"].include?($uri.scheme) || !$uri.is_a?(URI::HTTP)) then
    puts("Invalid scheme for KROKI_URL: #{$uri}");
    exit(1);
end

$http = Net::HTTP.new($uri.host, $uri.port);
if ($uri.scheme == "https") then
    $http.use_ssl = true;
end

def build_diagrams(ad_file)
    build_files = [];
    outputDir = "";

    puts "Processing #{ad_file} ..."

    File.foreach(ad_file) do |line|
        line.strip!
        if (line.start_with?("//")) then
            m = line.match(/\$AUTOBUILD ([\.A-Za-z0-9\-_]+)/);
            if (m != nil && File.exists?(m[1])) then
                build_files.push(m[1]);
            else
                m = line.match(/\$AUTOBUILDOUT ([A-Za-z0-9\-_]+)/);
                if (m != nil && Dir.exists?(m[1])) then
                    outputDir = m[1];
                end
            end
        end
    end

    dirname = File.absolute_path(File.dirname(ad_file));
    outputDir = File.absolute_path(File.join(dirname, outputDir));
    if (!outputDir.start_with?(dirname)) then
        puts("- invalid output dir: #{outputDir}! setting to default #{dirname}/assets");
        outputDir = File.join(dirname, "assets");
    else
        puts("- set output dir to: #{outputDir}");
    end

    build_files.uniq!

    for f in build_files do
        type = File.extname(f)[1..-1];
        out_file = type + "-" + File.basename(f, ".*") + ".svg";
        out_file = File.join(outputDir, out_file)
        puts "- build #{type}: #{f} => #{out_file}";

        request = Net::HTTP::Post.new("/#{type}/svg", {'Content-Type' => 'application/json'});
        request.body = ({ 'diagram_source' => IO.read(f) }).to_json;
        response = $http.request(request);

        if (response.code != "200") then
            puts "Failed to build #{graphfile}! kroki response: #{response.code}"
        else
            IO.write(out_file, response.body);
        end
    end
end

ad_files = Dir.glob("./**/*.{ad,adoc}")
ad_files.each{|f| build_diagrams(f) }