#!/usr/bin/env ruby1.9.1
#encoding: UTF-8

require 'optparse'
require 'pp'
require 'rest_client'
require 'fileutils'

serno="7375403532333702473232"
act=ARGV[0]
app=ARGV[1]

if not app or app=="" or app.length<4
  puts "Error: Must have App for build_app"
  exit -1
end

def ensure_dir d
  if  File.directory? d
    puts "#{d} Ok, Exists already"
  else
    if File.exist? d
      return "Error: #{d} exists but is not directory!"
    end
    FileUtils.mkdir d
    if File.directory? d
      puts "#{d} Created Ok"
    else
      return "Error: #{d} directory cannot be created!"
    end
  end
  false
end

abase="a/#{app}"
[abase,src_dir="#{abase}/src",build_dir="#{abase}/build",bin_dir="dist/app/#{app}"].each do |d|
  if err=ensure_dir(d)
    puts err
    exit -1
  end
end

def rester url
  JSON.parse(RestClient.get url, :content_type => :json, :accept => :json)
end
pp rester "http://20.20.20.21:3009/arm-db.json"

def swd serno,msg
  ret=rester "http://20.20.20.21:3000/rest/#{serno}/swd/#{msg}"
  #puts "swd(#{serno},#{msg}) ->"
  #pp ret
  if ret['error']
    return false
  else
    return ret
  end
end

def gcc msg,app,cpu,hw
  ret=rester "http://192.168.33.10:3000/kernel/#{msg}/#{app}/#{cpu}/#{hw}"
  #puts "gcc(#{msg},#{app},#{cpu},#{hw}) ->"
  #pp ret
  if ret['error']
    return {}
  else
    return ret
  end
end

if false
  if not swd(serno,"flash?srec_url=http://192.168.33.10:3000/kernel/appi.srec")
    puts "cannot find #{serno}"
  else
    while not swd(serno,"G")
      sleep 1
    end
  end
end

cpus=swd(serno,"IC")
if cpus==[]
  puts "Comms error! -- aborting"
  exit()
end

cpu=cpus['reply']
xapp=swd(serno,"IA")['reply']
hw=swd(serno,"IH")['reply']
app_start=swd(serno,"Ia")['reply'].to_i(16)

syms=gcc "syms",xapp,cpu,hw
pp syms["syms"]["appi"]
addr=syms["syms"]["appi"]["addr"]

printf "app sram addr=0x%08X\n",addr
printf "app flash addr=0x%08X\n",app_start

ld="""
SECTIONS {
  . = #{app_start};  /* 0x#{app_start.to_s(16)} */
  .text : {
    *(buut)
    *(stub)
    *(.text)
  }
  text_end = . ;
  .rodata : {
    *(work)
    *(.rodata)
    *(.rodata.*)
  }
  rodata_end = . ;
  _sidata = . ;
  . = #{addr}; /* 0x#{addr.to_s(16)} */
  .data : AT (_sidata) {
    _sdata = . ;
    *(.data)
    _edata = . ;
  }
  .bss : { _sbss = . ;
    *(.bss)
    _ebss = . ;
  }
}
"""

File.write "#{build_dir}/#{app}.ld", ld

target="#{bin_dir}/#{app}"


FileUtils.rm "#{target}" if File.exist? "#{target}"
FileUtils.rm "#{target}.srec" if File.exist? "#{target}.srec"

if act=="build"
  Dir["#{build_dir}/*.o"].each{ |file| FileUtils.rm file}
end

rantti=`rant -f Rantfile.rb APP=#{app}`
puts rantti
req=[]
objs=Dir["#{build_dir}/*.o"]
olist=""
objs.each do |o|
  olist+="#{o} "
end
`arm-eabi-objdump -t #{olist}|grep UND`.split("\n").each do |line|
  if line[/^(\h+)\s+(\*UND\*)\s+(\h+)\s+(.+)$/]
    #puts ">> #{$1},#{$2},#{$3},#{$4}"
    if $4[0]!="_"
      req<<$4
    end
  else
    #puts " Strange line: #{line}"
  end
end
pp req


of=File.open("#{src_dir}/stub.S", 'w')
of.write "  .syntax unified
  .cpu cortex-m3
  .fpu softvfp
  .thumb
  .section stub\n\n"

req.each do |sym|
  if s=syms["syms"][sym]
    puts "ok: #{sym}: #{s}"
    addr=s["addr"]
    if s["type"]=="F"
      of.write "  .type #{sym},%function\n"
      of.write "  .global #{sym}\n"
      of.write "  .set #{sym},0x#{(addr+1).to_s(16)}\n"
    else
      of.write "  .type #{sym},%object\n"
      of.write "  .global #{sym}\n"
      of.write "  .set #{sym},0x#{addr.to_s(16)}\n"
    end
  end
end

of.close()

rantti=`rant -f Rantfile.rb APP=#{app} ACT=#{act}`
puts rantti


lnk="arm-eabi-ld -M -EL --cref -Map #{build_dir}/mapfile -T #{build_dir}/#{app}.ld --no-undefined -o #{target} #{build_dir}/*.o 2>#{build_dir}/linker.err && arm-eabi-objcopy -O srec --srec-len 8 #{target} #{target}.srec"
puts lnk
`#{lnk}`

if not File.file? target
  puts "Linker Error! #{target} not made"
  exit();
else
  puts "#{target} created"
end

#FileUtils.cp "#{target}.srec","../kernel/appi.srec"
#FileUtils.cp "#{target}","../kernel/appi"
#puts "#{target} copied to ../kernel/appi"

#swd(serno,"Q")
#puts swd(serno,"flash_app?srec_url=http://192.168.33.10:3000/kernel/appi.srec")
#swd(serno,"G")
