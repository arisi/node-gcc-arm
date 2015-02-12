#! /usr/bin/env ruby
#encode : UTF-8
import "autoclean"
import "c/dependencies"
import "command"

if not var(:APP) or var(:APP).length<3
  puts "Error: APP must be specified"
  return
end

app=var(:APP)
act=var(:ACT)
puts "RANT: #{app} #{act}"

BASE_DIR = "a/#{app}"
BUILD_DIR = "#{BASE_DIR}/build"
SRC_DIR = "#{BASE_DIR}/src"

if not File.exist? BUILD_DIR
  puts "Error: App directory structure must exist #{BUILD_DIR}"
  return
end

puts "removing: '#{BUILD_DIR}/*.o'"
sys.rm_f "#{BUILD_DIR}/*.o"
sys.rm_f "#{BUILD_DIR}/*.err"
sys.rm_f "#{BUILD_DIR}/compile.log"

kernel="/projects/mygit/arisi/ctex"

defines=IO.read("#{kernel}/build/swd_STM32L_mg11/defines")
includes=IO.read("#{kernel}/build/swd_STM32L_mg11/includes")

begin
  build=IO.read("./build.def").to_i
rescue
  build=1
end
puts "BUILD NUMBER: #{build}"

incdir_gen="";
includes.split(" ").each do |i| #add kernel path
  if i!="-I"
    i="#{kernel}/#{i}"
  end
  incdir_gen+="#{i} "
end

SRC = FileList["#{SRC_DIR}/*.c","a/appman/*.c"]
ASM = FileList["#{SRC_DIR}/*.S"]

#LIBGCC=`arm-eabi-gcc #{defines} -print-libgcc-file-name`.gsub(/\n/,'')

SRC.each do |source|
  target = File.join(BUILD_DIR, source.sub(/.c$/, '.o').gsub(/\//,'_'))
  gen Command, target => source do |t|
    "arm-eabi-gcc -c -o #{t.name} -DBUILD=#{build} #{defines} #{incdir_gen} #{t.source} 2>#{t.name}.err"
  end
  task :default => target
end

ASM.each do |source|
  target = File.join(BUILD_DIR, source.sub(/.S$/, '.o').gsub(/\//,'_'))
    gen Command, target => source do |t|
      "arm-eabi-as -c -o #{t.name}  #{t.source}"
    end
  task :default => target
end


