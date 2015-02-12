#!/usr/bin/env coffee
#encoding: UTF-8

isWin = /^win/.test(process.platform);
isMac = /^darwin/.test(process.platform);
isLin = /^linux/.test(process.platform);
if not isWin and not isMac and not isLin
  console.log "Warning: Unsupported Platform: #{process.platform}, assuming Unix"
  isLin=true


CPATH="/projects/mygit/arisi/ctex"

stamp = () ->
  (new Date).getTime();


#async = require('async')
fs = require('fs');
exec = require("child_process").exec


parse_compile_log = (fn) ->
  log=fs.readFileSync(fn, 'utf8')
  path="./"
  errs={}
  for line in log.split("\n")
    if hit=line.match /(.+):(\d+):(\d+): fatal error: (.+)$/
      file=hit[1]
      errs[file]=[] if not errs[file]
      errs[file].push {row: hit[2], type: "error", txt: hit[4]}
    else if hit=line.match /(.+):(\d+):(\d+): (.+): (.+)$/
      file=hit[1]
      errs[file]=[] if not errs[file]
      errs[file].push {row: hit[2], type: hit[4], txt: hit[5]}
    else if hit=line.match /In file included from (.+):(\d+):(\d+):/
      file=hit[1]
      errs[file]=[] if not errs[file]
      errs[file].push {row: hit[2], type: "error", txt: "Included file Has Errors!"}
    else if hit=line.match /(.+):(\d+): undefined reference to (.+)$/
      row=hit[2]
      sym=hit[3]
      file=hit[1].replace("#{CPATH}/","")
      errs[file]=[] if not errs[file]
      errs[file].push {row: row, type: "error", txt: "LINKER: undefined reference to `#{sym}'"}
    else if hit=line.match /(.+):(.+): (.+)$/
      row=hit[2]
      sym=hit[3]
      file=hit[1] #.replace("#{CPATH}/","")
      errs[file]=[] if not errs[file]
      errs[file].push {row: row, type: "error", txt: "LINKER: `#{sym}'"}
  {errs: errs}

parse_elf = (fn,cb) ->
  start=stamp()
  syms={}
  vars={}
  console.log "parsing #{fn}"
  exec "arm-eabi-objdump -t #{fn}", (error, stdout, stderr) ->
    dur=stamp()-start
    console.log "parsed.. #{dur}"
    if error isnt null
      cb {result: "exec error: #{error}"}
      return
    for line in stdout.split("\n")
      #console.log ">>#{line}"
      if hit=line.match /^([0123456789abcdef]+)\s+(\w)\s+(\w)\s+(.+)\s+([0123456789abcdef]+)\s+(.+)$/
        #console.log hit
        syms[hit[6]]=
          addr: parseInt(hit[1],16)
          type: hit[3]
          size: parseInt(hit[5],16)
      else if hit=line.match /^([0123456789abcdef]+)\s+(\w)\s+(.+)\s+([0123456789abcdef]+)\s+(.+)$/
        #console.log "gloppali",hit
        if hit[2]!='l' and hit[5][0]=="_"
          vars[hit[5]]=
            addr: parseInt(hit[1],16)
            type: hit[2]
      #else
      #  console.log " Strange line: #{line}"
    cb {result: "ok",syms: syms,vars: vars,dur:dur}


#process.exit()

http = require("http")
express = require("express")
printf = require('printf');
sprintf = require('sprintf').sprintf;
yaml = require('js-yaml');
multer  = require('multer')


getUserHome = () ->
  process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE;

console.log "HOME:",getUserHome()

options={jee: ["joo","jyy",123]}

cfile="#{getUserHome()}/node-gcc-arm.yaml"
console.log "cfile:",cfile
try
  options = yaml.safeLoad(fs.readFileSync(cfile, 'utf8'));
  console.log options;
catch e
  console.log(e);
  console.log "no config!"
data=yaml.dump(options)
#console.log "->",data

#fs.writeFile cfile, data, "utf-8", () ->
#  #console.log "wrote ok",data


plist={}
plistp={}
sse_sc=1 #sessio counter
sse_list={}
app = express()

app.use(multer({ dest: './rest/'}))

console.log "workdir:",__dirname


app.get "/dist/kernel/:file.srec", (req, res) ->
  res.set('Content-Type', 'text/plain');
  console.log "get kernel #{req.params.file}.srec"
  res.send fs.readFileSync "#{__dirname}/dist/kernel/#{req.params.file}.srec", "ascii"

app.get "/dist/app/:app/:file.srec", (req, res) ->
  res.set('Content-Type', 'text/plain');
  console.log "get app #{req.params.app} #{req.params.file}.srec"
  res.send fs.readFileSync "#{__dirname}/dist/app/#{req.params.app}/#{req.params.file}.srec", "ascii"

app.get "/kernel/:file.json", (req, res) ->
  res.set('Content-Type', 'application/json');
  console.log "get kernel #{req.params.file}.json"
  res.send fs.readFileSync "#{__dirname}/kernel/#{req.params.file}.json", "utf-8"

app.get "/js/:page.js", (req, res) ->
  res.set('Content-Type', 'application/javascript');
  cof = fs.readFileSync "#{__dirname}/views/coffee/#{req.params.page}.coffee", "ascii"
  res.send cs.compile cof

app.get "/css/:page.css", (req, res) ->
  res.set('Content-Type', 'text/css');
  cof = fs.readFileSync "#{__dirname}/views/css/#{req.params.page}.css", "ascii"
  res.send cof

app.get "/:page.json", (req, res) ->
  #console.log "json",req.query,"params:",req.params
  res.json plist

app.get "/:page.sse", (req, res) ->
  #console.log "sse",req.query,"params:",req.params
  req.socket.setTimeout(Infinity);
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });
  res.write('\n');
  res.write "ok\n\n"
  messageCount = 0
  ses=sse_sc
  res.write('id: ' + messageCount + '\n');
  res.write("data: " + JSON.stringify({type: "init",ses: ses,options: options}) + '\n\n');
  messageCount++

  sse_sc+=1
  sse_list[ses]= (obj) ->
    messageCount++
    res.write('id: ' + messageCount + '\n');
    res.write("data: " + JSON.stringify(obj) + '\n\n');
  #plist2sse ses #send current state of ports to this new session

  req.on "close", () ->
    console.log "sse #{ses} closed"
    delete sse_list[ses]

app.get ["/ajax"], (req, res) ->
  #console.log "ajax:",req.query,"params:",req.params
  ret={}
  if req.query.act == "options"
    console.log "options",req.query.data
    options=req.query.data
    y=yaml.dump(options)
    fs.writeFile cfile, y, "utf-8", () ->
      console.log "wrote ok",y
      sse_out
        type: "options"
        options: options

  else if req.query.act == "send"
    for p,dev of plistp
      if dev.port
        dev.port.write "#{req.query.data}\n"
  else
    console.log "strange act",req.query.act
  res.json ret
  #res.json plist

app.get ["/:page.html","/:page.htm","/"], (req, res) ->
  console.log "doin haml:",req.query,"params:",req.params
  comp= hamlc.compile fs.readFileSync "#{__dirname}/views/index.haml", "ascii"
  str= comp
    plist: plist
  res.send str


app.post "/app/:act/:appname", (req, res) ->
  act=req.params.act
  appname=req.params.appname
  ret={}
  if act=="save" and appname and appname>""
    console.log "save"
    if not fs.existsSync("a/#{appname}")
      console.log "no app path #{appname}"
      ret.err="No App #{appname}"
    else
      for arg,f of req.files
        target="a/#{appname}/src/#{f.originalname}"
        console.log "file #{f.originalname} (#{f.path}) -> #{target}"
        fs.writeFileSync(target, fs.readFileSync(f.path))
      ret.save="ok"
  else
    ret.err="strange act #{act} post app"
  console.log ret
  res.json ret

app.get ["/kernel/:act/:app?/:cpu?/:hw?/:args?"], (req, res) ->
  ret={}
  act=req.params.act
  app=req.params.app
  cpu=req.params.cpu
  hw=req.params.hw
  args=req.params.args

  build="#{app}_#{cpu}_#{hw}"
  build_path="#{CPATH}/build/#{build}"
  srec_path="#{CPATH}/bin/#{build}.srec"
  elf_path="#{CPATH}/bin/#{build}"

  if act == "syms"
    parse_elf elf_path, (result) ->
      if args
        ret={}
        if result.syms[args]
          ret[args]=result.syms[args]
        else if result.vars[args]
          ret[args]=result.vars[args]
        res.json ret
      else
        res.json result
  else if act == "make" or act=="build"
    if not app or not cpu or not hw
      res.json {result: "fail", cause:"bad params"}
      return
    if not fs.existsSync("#{CPATH}/src/cpu/#{cpu}")
      res.json {result: "fail", cause:"Unsupported Cpu: #{cpu}"}
      return
    if not fs.existsSync("#{CPATH}/src/hw/#{hw}")
      res.json {result: "fail", cause:"Unsupported Hardware: #{hw}"}
      return
    if not fs.existsSync("#{CPATH}/src/app/#{app}")
      res.json {result: "fail", cause:"App does not exit: #{app}"}
      return

    console.log "compiling.. #{build}"
    result="ok"
    start=stamp()
    exec "cd #{CPATH}; rant -f Rantfile.rb --err-commands -v CPU=#{cpu} APP=#{app} HW=#{hw} ARGS=#{act}; cat #{build_path}/*.err >#{build_path}/compile.log", (error, stdout, stderr) ->
      console.log "compiled.."
      ret=parse_compile_log "#{build_path}/compile.log"
      ret.dur=stamp()-start
      if fs.existsSync(srec_path)
        ret.target_srec="http://192.168.33.10:3000/dist/kernel/#{build}.srec"
        ret.target_elf="http://192.168.33.10:3000/dist/kernel/#{build}"
        ret.result="ok"
        parse_elf elf_path, (elf_ret) ->
          ret.vars=elf_ret.vars
          res.json ret
      else
        ret.result="fail"
        res.json ret
  else
    res.json ret


app.get ["/app/:act/:appname/:args?"], (req, res) ->
  ret={}
  act=req.params.act
  appname=req.params.appname
  args=req.params.args

  build="#{appname}"
  build_path="a/#{appname}/build"
  src_path="a/#{appname}/src"
  srec_path="dist/app/#{appname}/#{appname}.srec"
  elf_path="a/#{appname}/bin/#{appname}"
  if not appname
    res.json {result: "fail", cause:"bad params, need appname"}
    return

  if act == "syms"
    parse_elf elf_path, (result) ->
      console.log result
      if args
        ret={}
        if result.syms[args]
          ret[args]=result.syms[args]
        else if result.vars[args]
          ret[args]=result.vars[args]
        res.json ret
      else
        res.json result
  else if act == "get"
    fn="#{src_path}/#{args}"
    if fs.existsSync fn
      res.setHeader("Access-Control-Allow-Origin", "*");
      data=fs.readFileSync fn, "ascii"
      res.send data
      return
    else
      res.json {err: "no such file '#{fn}'"}

  else if act == "ls"
    console.log "ls app: #{appname}"
    fs.readdir src_path, (err,files) ->
      if err
        res.json {err: err}
      else
        res.json {app: appname, files: files}

  else if act == "rm"
    console.log "rm app: #{appname}"
    fs.unlink "#{src_path}/#{args}", (err) ->
      if err
        res.json {err: err}
      else
        res.json {app: appname, rm: appname}

  else if act == "make" or act=="build"
    console.log "compiling.. app: #{build}"
    result="ok"
    start=stamp()
    cmd= "./build_app.rb #{act} #{appname} ; cat #{build_path}/*.err >#{build_path}/compile.log"
    console.log cmd
    exec cmd, (error, stdout, stderr) ->
      console.log "compiled..",stdout,stderr

      ret=parse_compile_log "#{build_path}/compile.log"
      ret.dur=stamp()-start
      if fs.existsSync(srec_path)
        ret.target_srec="http://192.168.33.10:3000/dist/app/#{appname}/#{build}.srec"
        ret.target_elf="http://192.168.33.10:3000/dist/app/#{appname}/#{build}"
        ret.result="ok"
        parse_elf elf_path, (elf_ret) ->
          ret.vars=elf_ret.vars
          res.json ret
      else
        ret.result="fail"
        res.json ret
  else
    res.json ret



app.use (req, res) ->
  #console.log "def:",req
  #res.setHeader("Access-Control-Allow-Origin", "*");
  path=req._parsedUrl.pathname
  if (fs.existsSync("#{__dirname}/views/#{path}"))
    cof = fs.readFileSync "#{__dirname}/views/#{path}", "ascii"
    res.send cof
  else
    res.send(404);


app.listen 3000

sse_out = (obj) ->
  for ses,sse of sse_list
    sse obj




