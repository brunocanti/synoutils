#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require 'fileutils'

#Global Variables
$skipcon = false
$ext_videos = %w(.asf .avi .divx .iso .m1v .m2p .m2t .m2ts .m2v .m4v .mkv .mov .mp4 .mpeg4 .mpe .mpg .mpg4 .mts .qt .rm .trp .ts .vob .wmv .xvid)
$ext_zip = %w(.rar .zip)
$ext_legendas = %w(.sub .srt)
$tagbusca = ''
$rootdir = '/volume1/downloads/*'
$completedir = '/volume1/downloads/complete/'
$backupdir = '/volume1/downloads/complete/backup/'
$mediadir = '/volume1/video/'
$addedmedia = false
$syno_index_error_msg = 'Failed to get MediaInfo.'


def autenticado_como(usuario, senha)
  @agente = Mechanize.new
  @pagina_inicial = @agente.get('http://legendas.tv')

  form = @pagina_inicial.form_with(:action => 'login_verificar.php')
  form['txtLogin'] = usuario
  form['txtSenha'] = senha

  @agente.submit(form)

  yield
end

def buscar
  form = @pagina_inicial.form_with(:action => 'index.php?opcao=buscarlegenda')
  form['txtLegenda'] = "#{$tagbusca}"

  pagina = @agente.submit(form)
  pagina.search('#conteudodest > div > span').each_with_index do |s, posicao|
    elemento_id = s.search('.buscaDestaque', '.buscaNDestaque')
    elemento_nome = s.search('.brls')
    id = elemento_id.attr('onclick').text
    id = id.gsub(/(javascript|abredown|[^a-zA-Z0-9])/, '')
    nome = elemento_nome.text

    yield id, nome, posicao
  end
end

def escolher(legendas,dname,fname)
  numero = nil
	  case legendas.length
		when 0
		   print "Legenda nao encontrada(legendas.tv): \"#{fname}\"  - Tag : #{$tagbusca} \n"
		when 1
		   numero = '0'
		else
      if $skipcon
        print "Legenda 0 escolhida - \"#{fname}\"  - Tag : #{$tagbusca} \n"
        numero = '0'
      else
        print "Informe o numero para a Legenda (\"#{fname}\"\) \n"
        numero = STDIN.gets.chomp
      end
    end

	 unless numero.nil? and numero != 'x'
		nomearq = baixar legendas[numero.to_i], dname
		print "Download do arquivo: \"#{nomearq}\"  completo.\n"
	 end
end

def baixar(id, namedir)
  arquivo = @agente.get("http://legendas.tv/info.php?d=#{id}&c=1")

  arquivo.save File.join(namedir, arquivo.filename)
  descompactar File.join(namedir, arquivo.filename)
  arquivo.filename
end

def descompactar(filename)

	  case File.extname(filename).downcase
		when '.rar'
		  command = "unrar e -y -o+ -p- \"#{filename}\" \"#{File.dirname(filename)}\" >/dev/null"
          #print " rar  : \"#{command}\"\n"
		when '.zip'
	      command = "unzip -qqo #{filename} -d #{File.dirname(filename)}"
          #print " zip  : \"#{command}\"\n"
		else
          print "Compactacao Invalida \n"
          command = 'echo "Ferrou"'
    end

   success = system(command)
   FileUtils.rm Dir[filename]

   success && $?.exitstatus == 0
end

def legenda_existe(sdir)
  File.directory?(sdir) ?
      Dir.glob(File.join(sdir.to_s, '*.srt')).size>0 :
      Dir.glob("#{File.join(File.dirname(sdir.to_s), File.basename(sdir.to_s, '.*'))}.srt").size>0
end

def busca_legendas_dir(d)

  autenticado_como 'brunocanti', 'nasser' do
  print "Autenticado\n"

      Dir[d].each.map do |x|
        unless File.directory?(x)
          sfname = File.basename(x, '.*')
          drname = File.dirname(x)
          next if not $ext_videos.include?(File.extname(x))
          tipo, snome, ano_episodio = tvshow_or_movie(sfname)
          if !legenda_existe(x) and !tipo.eql?('other')
            legendas = Array.new
            #busca pelo filename
            $tagbusca = sfname
            buscar  do |id, nome, posicao|
              legendas << id
              print "#{posicao.to_s}. #{nome}\n"
            end
            #se nao encontra busca por tag
            if legendas.length == 0
              $tagbusca = snome+' '+ano_episodio
              buscar  do |id, nome, posicao|
                legendas << id
                print "#{posicao.to_s}. #{nome}\n"
              end
            end
            escolher legendas, drname, sfname
          else
            print "Legenda ja existe:  #{sfname}\n"
          end
        end
      end
   analizadownload
  end
end

def analizadownload
analizadir(File.dirname($rootdir))
analizadir($rootdir)
end

def limpalixo(dir)
#FileUtils.cd("#{File.dirname($rootdir)}")
#print FileUtils.pwd
#print "\nfor file in *; do mv \"$file\" `echo $file | sed -e 's/ /./g'`; done \n"
    print "Limpando lixo :  #{dir}\n"

    system("rm -Rf #{dir}/@eadir")

       mask_excluir = %w(*Legendas.tv* *.nzb *.nfo *.par2_hellanzb_dupe0 *.sfv *.srr *.nfo *.txt *.com *.segment000[0-9] *.idx *.sub* *.jpg *.jpeg)
       mask_excluir.each do |vmask|
           FileUtils.rm_r Dir[ File.join(dir, vmask)]
       end

    unless File.basename(dir).eql?('downloads')
      FileUtils.rm Dir[ File.join(dir, '*.srt')]
    end
    system("find #{dir} -maxdepth 1 -name \"*www*\" | while read file; do mv \"$file\" `echo $file | sed 's/\(\[\|\(\).*\(\]\|\)\)\s*\-\s*//g'`; done")
    system("find #{dir} -maxdepth 1 -name \"* *\" | while read file; do mv \"$file\" `echo $file | sed -e 's/ /./g'`; done")
    system("find #{dir} -maxdepth 1 -name \"*\\[*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\\[/./g'`; done")
    system("find #{dir} -maxdepth 1 -name \"*\\]*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\\]/./g'`; done")
    system("find #{dir} -maxdepth 1 -name \"*(*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/(//g'`; done")
    system("find #{dir} -maxdepth 1 -name \"*)*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/)//g'`; done")
    system("find #{dir} -maxdepth 1 -name \"*\\'*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\\'//g'`; done")
    #system("find #{dir} -maxdepth 1 -name \"*..*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\.\././g'`; done")
    #system("find #{dir} -maxdepth 1 -name \"*...*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\.\.\././g'`; done")
    #system("find #{dir} -maxdepth 1 -name \"..*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\.\.//g'`; done")
    #system("find #{dir} -maxdepth 1 -name \"...*\" | while read file; do mv \"$file\" `echo $file | sed -e 's/\.\.\.//g'`; done")
    #Arquivos Sample
		FileUtils.rm_r Dir[ File.join(dir, '*[.-][Ss][Aa][Mm][Pp][Ll][Ee][.-]*.{mkv,avi,mpg,srs,mp4}') ]
		FileUtils.rm_r Dir[ File.join(dir, '*[.-][Ss][Aa][Mm][Pp][Ll][Ee].{mkv,avi,mpg,srs,mp4}') ]
		FileUtils.rm_r Dir[ File.join(dir, '[Ss][Aa][Mm][Pp][Ll][Ee][.-]*.{mkv,avi,mpg,srs,mp4}') ]
		FileUtils.rm_r Dir[ File.join(dir, '*[Ss][Aa][Mm][Pp][Ll][Ee].{mkv,avi,mpg,srs,mp4}') ]
end

def analizadir(d)
print "Analizando:  #{d}\n"
	Dir[d].each.map do |x|
    # print "Linha 1:  #{x.to_s}\n"
	  if File.directory?(x)
			sfname = File.basename(x)
			drname = x.to_s
	  	next if  sfname.eql?('complete') #or tvshow_or_movie(sfname).eql?('other')

      limpalixo(drname)

        unless sfname.eql?('downloads')
          Dir[x+'/*'].each.map do |xd|
        	 # print "Linha - 2 - :  #{xd.to_s}\n"
            subfname = File.basename(xd)
            subextname = File.extname(xd)
            if  $ext_videos.include?(subextname) # and  !tvshow_or_movie(subfname).eql?('other')
              #copia o nome do di  o tamanho do nome do diretorio for maior q o do arquivo
              #senao usa o mesmo nome
             # print "Linha - 3 - :  #{subfname.length} #{sfname.length}\n"
              if subfname.length < sfname.length and tvshow_or_movie(sfname).eql?('movie')
                print "cp #{xd.to_s} #{x}#{subextname}  \n"
                system("cp #{xd.to_s} #{x}#{subextname}")
              else
                print "cp -Rf #{xd.to_s} #{File.dirname($rootdir)}/ \n"
                system("cp -Rf #{xd.to_s} #{File.dirname($rootdir)}/")
              end
            else
              #print "Linha - 4 - :  #{xd.to_s} #{x.to_s}\n"
              print "cp -Rf #{xd.to_s} #{File.dirname($rootdir)}/ \n"
              system("cp -Rf #{xd.to_s} #{File.dirname($rootdir)}/ ")
            end
          end
          print "Diretorio Deletado : #{drname}  #{Dir.entries(drname).size-2} arquivo(s) promovidos para  #{File.dirname($rootdir)} \n"
          system("mv -f #{drname} #{$backupdir}")
        end

	  else
      sfname = File.basename(x, '.*')
      drname = File.dirname(x)
      descompactar(x) if $ext_zip.include?(File.extname(x))
      if  $ext_videos.include?(File.extname(x)) and !tvshow_or_movie(sfname).eql?('other')
        legenda_existe(x) ? move_complete(drname, sfname, '*.*') : encontra_legenda_similar(x)
      end
	  end
  end
end

def move_complete(dr,fl,mask)
	 print "Movendo:  #{fl}\n"
   print dr+'/'+fl+mask+"\n"
	 FileUtils.mv(Dir.glob(dr+'/'+fl+mask),$completedir,:force => true )
   $addedmedia = true
end

def string_difference_percent(a, b)
  longer = [a.size, b.size].max
  same = a.each_char.zip(b.each_char).select { |a,b| a == b }.size
  (longer - same) / a.size.to_f
end

def encontra_legenda_similar(arqvideo)
    maxdiff = 0.60
    mdiff = maxdiff
    arqsimilar = 'Nao Encontrado'
	  Dir[$rootdir+'.srt'].each.map do |arqsrt|
	   #print "Linha 1 : #{arqsrt} - Dir : #{$rootdir+'.srt'} \n"	
     #next if !$ext_legendas.include?(File.extname(arqsrt))
	   a = File.basename(arqvideo, '.*').upcase
	   b = File.basename(arqsrt, '.*').upcase
	   diff = string_difference_percent(a,b)
	   print "Video : #{a} - Legenda : #{b} - Comparacao : #{diff} \n" if !$skipcon
	    if diff < mdiff
	        arqsimilar = arqsrt
	        mdiff = diff
	    end
    end

    if mdiff < maxdiff
       print "Arquivo similar :  \"#{File.basename(arqvideo)}\" : #{File.basename(arqsimilar)} - #{mdiff}\n"
       if $skipcon
         brenomear = true
       else
         print "Renomear arquivo? \n"
         brenomear = STDIN.gets.chomp.eql?('y')
       end
       if brenomear
           #print "mv #{arqsimilar}  #{File.dirname(arqvideo)}/#{File.basename(arqvideo,".*")}.srt \n"
           FileUtils.mv(arqsimilar,File.dirname(arqvideo)+'/'+File.basename(arqvideo, '.*')+'.srt',:force => true )
           move_complete(File.dirname(arqvideo),File.basename(arqvideo, '.*'), '*.*')
       end
    else
      print "Nenhuma legenda valida encontrada :  \"#{File.basename(arqvideo)}\" \n"
    end
end

def distribui_complete
  Dir["#{$completedir}*.*"].each.map do |arqcomplete|
    a = File.basename(arqcomplete)
    #b = "#{File.dirname(arqcomplete)}/#{File.basename(arqcomplete, '.*')}*.*"
    #print "Linha:  #{arqcomplete.to_s}\n"
    if  $ext_videos.include?(File.extname(arqcomplete)) or $ext_legendas.include?(File.extname(arqcomplete))
      command = nil
      #tvshow =  a.match('(?i)(?:s|season)\d\W?(\d{1,2})\D*(\d{1,2})|[\._ \-]([0-9]+)x([0-9]+)|[\._ \-]\d{1,3}[\._ \-]') != nil
      #print "Linha 2:  #{a.to_s} - #{tvshow} \n"
      tipo, nome = tvshow_or_movie(a)

      tipo.eql?('tvshow') ?
          command = "filebot -rename #{arqcomplete}  --db thetvdb  --output /volume1/video/Series --format \"{n}/Season {s}/{n.space('.')}.{s00e00}.{t.space('.')}.{group}\" --conflict override -non-strict" :
          if tipo.eql?('movie')
            c= File.basename(nome, '*')
            command = "filebot -rename \"#{arqcomplete}\" --q \"#{c}\" --db imdb --format \"/volume1/video/Movies/{n.upperInitial()}/{n.upperInitial().space('.')}.{y}.{source}\"  --conflict override -non-strict"
          end

      if command != nil
        print(command+"\n")
        system(command) if !nil?
      else
        print "DistErro:TIPO DE ARQUIVO NAO ENCONTRADO :  #{a} \n"
      end
    end
  end
  #limpa legendas nao utilizadas
  reindex_media if $addedmedia
  FileUtils.rm Dir["#{$rootdir}.srt"] if $skipcon
end

def tvshow_or_movie(fname)
   # print(fname+": titulo da parada \n ")
		if fname.match('(?i)(?:s|season)\d\W?(\d{1,2})\D*(\d{2})|[\._ \-]([0-9]+)x([0-9]+)|[\._ \-]\d{3}[\._ \-]') != nil
	    vsname = fname.match('^(?<sname>[^\\\]+?)[ _.\-]+(?i)[s\.\s\d]').captures
	    vepisode = fname.match('(?<episode>(?i)(?:s|season)\d\W?(\d{1,2})\D*(\d{1,2})|[\._ \-]([0-9]+)x([0-9]+)|[\._ \-]\d{1,3}[\._ \-])').captures
		  return 'tvshow',vsname[0],vepisode[0]
		else
      	if fname.match('^(?:.*\\\)?(?<movie>[^\\\]+?)[ _.\-]+(?:(?:cd[ _.\-\[\]]*)?(?<year>\d+))') != nil
	   	    vmovie, vyear = fname.match('^(?:.*\\\)?(?<movie>[^\\\]+?)[ _.\-]+(?:(?:cd[ _.\-\[\]]*)?(?<year>\d+))').captures
	   	    return 'movie',vmovie,vyear
	     	else return 'other'
       	end
	  end
end

def reindex_media
  Dir.glob($mediadir+'**/*.*').select{|f| File.mtime(f) > (Time.now - (60*60*2)) }.each do |f|
    if  $ext_videos.include?(File.extname(f)) and !File.directory?(f)
      outp = `synoindex -g \"#{f}\" -t video `
      #print outp.chomp +  "\n"
      if outp.chomp.eql?($syno_index_error_msg)
        print " Indexando arquivo : #{f}  \n"
        `synoindex -a \"#{f}\"`
      end
    end
  end
end


print "Iniciando script\n"
$skipcon = ARGV[0].eql?('-q')
#$rootdir = ARGV[2].to_s if ARGV[1] != nil

print "Root diretorio : \"#{$rootdir}\"\n"
print "Skip Conflict : \"#{$skipcon}\"\n"

analizadownload
busca_legendas_dir($rootdir)
distribui_complete

reindex_media

=begin
tipo, nome, ano = tvshow_or_movie('Cannibal.Holocaust.Uncut.1980.DVDRip.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Hyde.Park.On.Hudson.2012.DVDSCR.XviD-NYDIC.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Closer.2004.BRRip.XviD-VLiS.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Anna Karenina 2012 DVDSCR.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Book of Dragons 2011 BDRIP XVID-WBZ.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Spanish.Apartment.2003.XviD.AC3.2CD-WAF.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('The.Russian.Dolls.2005.DVDRip.XviD-ESPiSE.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.S01E02.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.102.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.1x01.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show name - 1x02 Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.S01E02.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show Name - S01E02 - My Ep Name.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.S01.E03.My.Ep.Name.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show.Name.S01E02E03.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Show Name - S01E02-03 - My Ep Name.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Californication.S01.E02.E03.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('Cougar.Town.S04E13.HDTV.x264-2HD.mp4')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('The.Walking.Dead.S01E02.Fonte.Quality.Etc-Group.avi')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "

tipo, nome, ano = tvshow_or_movie('TTS_Pro_Loquendo_Voices.rar')
print "\n "+tipo+"\n "+nome+"\n "+ano+"\n "
=end
