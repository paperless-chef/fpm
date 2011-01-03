#!/usr/bin/env ruby
#

require "optparse"
require "ostruct"
require "json"

settings = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.on("-n PACKAGENAME", "--name PACKAGENAME",
          "What name to give to the package") do |name|
    settings.name = name
  end

  opts.on("-v VERSION", "--version VERSION",
          "version to give the package") do |version|
    settings.version = version
  end
end

args = opts.parse(ARGV)

#builddir="#{Dir.pwd}/npm2pkg-#{settings.name}-#{settings.version or "latest"}"
builddir="#{Dir.pwd}/npm2pkg"
#if File.exists?(builddir)
  #system("rm -r #{builddir}")
#end

INSTALLPATH="/usr/lib/node"
Dir.mkdir(builddir) if !File.exists?(builddir)
File.open("#{builddir}/.npmrc", "w") do |file|
  file.puts "root = #{builddir}#{INSTALLPATH}"
end

## Trick npm into using a custom .npmrc
system("env - PATH=$PATH HOME=#{builddir} npm install #{settings.name} #{settings.version}")

# Find all installed npms in builddir, make packages.
Dir.glob("#{builddir}#{INSTALLPATH}/.npm/*/*") do |path|
  next if File.symlink?(path)
  puts path

  # Load the package.json and glean any information from it, then invoke pkg.rb
  package = JSON.parse(File.new("#{path}/package/package.json").read())
  depends = Dir.glob("#{path}/dependson/*@*").collect { |p| File.basename(p) }\
    .collect { |p| n,v = p.split("@"); "#{n} (= #{v})" }

  require "rubygems"
  require "ap"
  ap package
  if package["author"]
    maintainer = package["author"]
  else
    m = package["maintainers"][0] \
      rescue { "name" => "missing upstream author", "email" => ENV["USER"] }
    maintainer = "#{m["name"]} <#{m["email"]}>"
  end

  pkgcmd = [ "ruby", "bin/pkg.rb", 
    "-n", "nodejs-#{package["name"]}",
    "-v", package["version"],
    "-m", maintainer,
    "-a", "all",
  ]

  depends.each do |dep|
    pkgcmd += ["-d", dep]
  end

  pkgcmd += ["-p", "nodejs-#{package["name"]}-VERSION_ARCH.deb"]
  pkgcmd += ["-C", builddir]
  pkgcmd << "#{INSTALLPATH[1..-1]}/.npm/#{package["name"]}/active"
  pkgcmd << "#{INSTALLPATH[1..-1]}/#{package["name"]}"
  pkgcmd << "#{INSTALLPATH[1..-1]}/#{package["name"]}@#{package["version"]}"

  puts pkgcmd.map { |x| "\"#{x}\"" }.join(" ")
  system *pkgcmd
end