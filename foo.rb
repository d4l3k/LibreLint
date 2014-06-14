0 # It was the night before Christmas and all through the house, not a creature was coding: UTF-8, not even with a mouse.
0 require 'bundler'
0 require 'sass'
0 Bundler.require(:default)
0 require 'tempfile'
0 require 'digest/md5'
0 
0 # Load the JSON+Comments configuration file.
0 require_relative 'strip_json_comments'
0 $config = MultiJson.load(
1     "{\n"+
1     JSONComments.strip(File.open('./config/config.json').read)+
0 "\n}")
0 
0 # Don't load databases if running rake tasks.
0 if not ENV["CONFIGMODE"]
1     require_relative 'models'
1     require_relative 'configure'
0 end
0 require_relative 'util'
0 require_relative 'helpers'
0 require_relative 'raw_upload'
0 require_relative 'webdav'
0 
0 class WebSync < Sinatra::Base
1     register Sinatra::Flash
1     use Rack::Logger
1     use Rack::RawUpload
1     use Rack::Locale
1     helpers do
2         include Helpers
1     end
1     configure :development do
2         Bundler.require(:development)
2         set :assets_debug, true
2         use PryRescue::Rack
1     end
1     
1     configure :production do
2         Bundler.require(:production)
2         set :assets_css_compressor, :sass
2         set :assets_js_compressor, :closure
2         set :assets_precompile, %w(default.css edit.css bundle-norm.js bundle-edit.js theme-*.css) # *.woff *.png *.favico *.jpg *.svg *.eot *.ttf
2         no_digest = Dir.glob(File.join(root, 'assets', 'js', '{src,lib}', "*.js")).map{|f| f.split("/").last}
2         set :assets_precompile_no_digest, no_digest
2         OmniAuth.config.full_host = $config["host_url"]
1     end
1     configure :test do
2         set :raise_errors, true
2         set :dump_errors, true
2         set :show_exceptions, false
2         set :assets_debug, true
2         # This is kind of a hack. This allows dynamic files in test mode.
2         app = self
2         get '/assets/*' do |key|
3             if Sprockets::Helpers.digest
4                 key.gsub! /(-\w+)(?!.*-\w+)/, ""
3             end
3             asset = app.sprockets[key]
3             content_type asset.content_type
3             if Sprockets::Helpers.expand
4                 return asset.body
3             end
3             asset.to_s
2         end
1     end
1     configure do
2         set :public_folder, File.dirname(__FILE__) + '/../public'
2         set :views, File.dirname(__FILE__)+"/../views"
2         use Rack::Session::Cookie, :expire_after => 60*60*24*7, :secret => $config['session_secret']
2         enable :sessions
2         set :session_secret, $config['session_secret']
2         set :server, 'thin'
2         disable :show_exceptions
2         disable :raise_errors
2         set :template_engine, :erb
2         
2         I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
2         I18n.load_path = Dir[File.join(settings.root, '..', 'locales', '*.yml')]
2         I18n.backend.load_translations
2         register Sinatra::AssetPipeline
2         #sprockets.append_path File.join(root, 'assets', 'css')
2         sprockets.append_path File.join(root, 'assets', 'digest')
2         sprockets.append_path File.join(root, 'assets', 'src')
2         sprockets.append_path File.join(root, 'assets', 'lib')
2         
2         # OmniAuth configuration
2         use OmniAuth::Builder do
3             def style provider, color, tag
4                 $config["omniauth"] ||= {}
4                 $config["omniauth"][provider.to_sym] = {color: color, tag: tag}
3             end
3             # This is a huge hack.
3             eval(File.read('./config/omniauth-providers.rb'))
2         end
1     end
1     # Block most XHR (originated from javascript). This stops scripts from doing anything malicious to other documents.
1     before do
2         # Allow static assets.
2         if request.xhr? and not request.path_info.match %r{^/assets/}
3             referer = URI.parse(request.env["HTTP_REFERER"]).path
3             path = request.path_info
3             bits = referer.split("/")
3             doc = bits[1]
3             # Only allow same document and post "upload" and get "assets/#{asset}".
3             if bits.length < 2 or not (
5                     request.post? and path.match %r{^/#{doc}/upload$} or
4                 request.get?  and path.match %r{^/#{doc}/assets/} )
4                 halt 403
3             end
2         end
1     end
1     # OmniAuth: Support both GET and POST for callbacks
1     %w(get post).each do |method|
2         send(method, "/auth/:provider/callback") do
3             env['omniauth.auth'] # => OmniAuth::AuthHash
3             if logged_in?
4                 flash[:danger] = "<strong>Error!</strong> Already logged in!"
4                 redirect '/'
3             else
4                 hash = env["omniauth.auth"]
4                 email = hash["info"]["email"].downcase
4                 provider = hash['provider']
4                 nice_provider = $config["omniauth"][provider.to_sym][:tag]
4                 user = User.get(email)
4                 if user.nil?
5                     user = User.create({email: email, password: "", origin: provider})
4                 elsif not user.origin.split(',').include?(provider)
5                     flash[:danger] = "<strong>Error!</strong> #{email} is not enabled for #{nice_provider} login."
5                     redirect '/login'
4                 end
4                 puts "[OAuth Login] #{email} #{provider}"
4                 session_key = SecureRandom.uuid
4                 $redis.set("userhash:#{session_key}",email)
4                 session['userhash']=session_key
4                 session['user']=email
4                 redirect '/'
3             end
2         end
1     end
1     get '/public' do
2         cache time: 30 do
3             erb :public
2         end
1     end
1     get '/login' do
2         if !logged_in?
3             cache do
4                 erb :login
3             end
2         else
3             flash[:warning]="Already logged in."
3             redirect '/'
2         end
1     end
1     post '/login' do
2         redirect_loc = '/'
2         if params[:redirect]!=''
3             redirect_loc = params[:redirect]
2         end
2         if authenticate params[:email],params[:password]
3             redirect redirect_loc
2         else
3             flash[:danger]="<strong>Error!</strong> Incorrect username or password."
3             redirect "/login?#{redirect_loc}"
2         end
1     end
1     get '/register' do
2         redirect '/login'
1     end
1     post '/register' do
2         if register params[:email],params[:password]
3             redirect '/'
2         else
3             flash[:danger]="<strong>Error!</strong> Failed to register. Account might already exist?"
3             redirect '/login'
2         end
1     end
1     get '/logout' do
2         if logged_in?
3             logout
2         end
2         redirect '/login'
1     end
1     not_found do
2         erb :error, locals:{error: "404", reason: "Page or document not found."}
1     end
1     error 403 do
2         erb :error, locals:{error: "403", reason: "Access denied."}
1     end
1     error 400 do
2         erb :error, locals:{error: "400", reason: "Invalid request."}
1     end
1     error 500 do
2         erb :error, locals:{error: "500", reason: "The server failed to handle your request."}
1     end
1     get '/' do
2         @javascripts = []
2         if logged_in?
3             erb :file_list
2         else
3             cache do
4                 erb :index
3             end
2         end
1     end
1     get '/deleted' do
2         login_required
2         erb :deleted
1     end
1     get '/documentation' do
2         cache do
3             erb :documentation
2         end
1     end
1     get '/documentation/:file.:ext' do
2         cache do
3             file = "docs/#{params[:file]}.html"
3             if Dir.glob("docs/*.html").include? file
4                 File.read file
3             else
4                 halt 404
3             end
2         end
1     end
1     get '/settings' do
2         login_required
2         erb :settings
1     end
1     post '/settings' do
2         login_required
2         user = current_user
2         user.theme = Theme.get(params["theme"])
2         if params["new_password"]!=""
3             if user.password == params["cur_password"]
4                 if params["new_password"] == params["rep_new_password"]
5                     user.password = params["new_password"]
4                 else
5                     flash.now[:danger] = "Passwords don't match."
4                 end
3             else
4                 flash.now[:danger] = "Incorrect password."
3             end
2         end
2         provider_list = params.keys.select{|k| k.include? "provider"}
2         .map{|checkbox| checkbox.split(":").last}
2         provider_string = provider_list.join(",")
2         if not provider_list.empty?
3             if user.origin != provider_string
4                 if provider_list.include? "local" and user.password == ""
5                     flash.now[:danger] = "You have to set a password to use the local login."
4                 else
5                     flash.now[:success] = "Updated providers."
5                     user.origin = provider_string
4                 end
3             end
2         else
3             flash.now[:danger] = "You have to specify a login method."
2         end
2         user.save
2         erb :settings
1     end
1     get '/admin' do
2         admin_required
2         erb :admin
1     end
1     get '/admin/users' do
2         admin_required
2         erb :admin_users
1     end
1     get '/admin/assets' do
2         admin_required
2         erb :admin_assets
1     end
1     get '/admin/assets/:asset/edit' do
2         admin_required
2         erb :admin_assets_edit
1     end
1     get '/admin/assets/:asset/delete' do
2         admin_required
2         ass = Asset.get(params[:asset])
2         if not ass.nil?
3             ass.destroy
2         end
2         redirect '/admin/assets'
1     end
1     post '/admin/assets/:asset/edit' do
2         admin_required
2         ass = Asset.get(params[:asset])
2         if not ass.nil?
3             ass.name = params[:name]
3             ass.description = params[:desc]
3             ass.url = params[:url]
3             ass.type = params[:type]
3             ass.save
2         else
3             n_ass = Asset.create(:name=>params[:name],:description=>params[:desc],:url=>params[:url], :type=>params[:type])
3             n_ass.save
2         end
2         redirect '/admin/assets'
1     end
1     get '/admin/asset_groups/:asset/edit' do
2         admin_required
2         erb :admin_asset_groups_edit
1     end
1     get '/admin/asset_groups/:asset_group/:asset/add' do
2         admin_required
2         ass = AssetGroup.get(params[:asset_group])
2         ass.assets << Asset.get(params[:asset])
2         ass.save
2         redirect "/admin/asset_groups/#{params[:asset_group]}/edit"
1     end
1     get '/admin/asset_groups/:asset_group/:asset/remove' do
2         admin_required
2         ass = AssetGroup.get(params[:asset_group])
2         ass.assets.each do |a|
3             if a.id==params[:asset].to_i
4                 ass.assets.delete a
3             end
2         end
2         ass.save
2         redirect "/admin/asset_groups/#{params[:asset_group]}/edit"
1     end
1     get '/admin/asset_groups/:asset/delete' do
2         admin_required
2         ass = AssetGroup.get(params[:asset])
2         if not ass.nil?
3             ass.assets = []
3             ass.save
3             ass.destroy
2         end
2         redirect '/admin/assets'
1     end
1     post '/admin/asset_groups/:asset/edit' do
2         admin_required
2         ass = AssetGroup.get(params[:asset])
2         if not ass.nil?
3             ass.name = params[:name]
3             ass.description = params[:desc]
3             ass.save
2         else
3             n_ass = AssetGroup.create(:name=>params[:name],:description=>params[:desc])
3             n_ass.save
2         end
2         redirect '/admin/assets'
1     end
1     get '/new/:group' do
2         login_required
2         group = AssetGroup.get(params[:group])
2         if group.nil?
3             halt 400
2         end
2         doc = WSFile.create(
3             name: "Unnamed #{group.name}",
3             body: {body:[]},
3             create_time: Time.now,
3             edit_time: Time.now,
3             content_type: 'text/websync'
2         )
2         doc.assets = group.assets
2         doc.save
2         perm = Permission.create(user: current_user, file: doc, level: "owner")
2         redirect "/#{doc.id.encode62}/edit"
1     end
1     get '/upload' do
2         login_required
2         cache do
3             erb :upload
2         end
1     end
1     post '/upload' do
2         login_required
2         if params[:file]==nil
3             redirect "/upload"
2         end
2         tempfile = params[:file][:tempfile]
2         filename = params[:file][:filename]
2         filetype = params[:file][:type]
2         content = nil
2         # TODO: Split upload/download into its own external server. Right now Unoconv is blocking. Also issues may arise if multiple copies of LibreOffice are running on the same server. Should probably use a single server instance of LibreOffice
2         if params["convert"]
3             if filetype=="application/pdf"
4                 content = PDFToHTMLR::PdfFilePath.new(tempfile.path).convert.force_encoding("UTF-8")
3             elsif filetype=='text/html'
4                 content = File.read(tempfile.path)
3             else
4                 system("unoconv","-f","html",tempfile.path)
4                 exit_status = $?.to_i
4                 if exit_status == 0
5                     content = File.read(tempfile.path+".html")
5                     File.delete(tempfile.path + ".html")
4                 else
5                     logger.info "Unoconv failed and Unrecognized filetype: #{params[:file][:type]}"
4                 end
3             end
3             File.delete tempfile.path
3             if content!=nil
4                 dom = Nokogiri::HTML(content)
4                 upload_list = []
4                 dom.css("img[src]").each do |img|
5                     path = img.attr("src").split("/").last
5                     # Security check, make sure it starts with RackMultipart and it exists.
5                     if File.exists? "/tmp/#{path}" and /^#{tempfile.path}/.match img.attr("src")
6                         upload_list.push path
6                         img["src"] = "assets/#{path}"
5                     end
4                 end
4                 # Basic security check
4                 dom.css("script").remove();
4                 doc = WSFile.create(
5                     name: filename,
5                     body: {html: dom.to_html},
5                     create_time: Time.now,
5                     edit_time: Time.now,
5                     content_type: 'text/websync'
4                 )
4                 doc.assets = AssetGroup.get(1).assets
4                 doc.save
4                 perm = Permission.create(user: current_user, file: doc, level: "owner")
4                 # Upload images
4                 upload_list.each do |file|
5                     path = "/tmp/#{file}"
5                     type = MIME::Types.type_for(path).first.content_type
5                     blob = WSFile.create(parent: doc, name: file, content_type: type, edit_time: DateTime.now, create_time: DateTime.now)
5                     blob.data = File.read path
5                     perm = Permission.create(user: current_user, file: blob, level: "owner")
5                     File.delete path
4                 end
4                 if doc.id
5                     flash[:success] = "'#{h params[:file][:filename]}' was successfully converted."
5                     redirect "/#{doc.id.encode62}/edit"
4                 else
5                     flash[:danger] = "'#{h params[:file][:filename]}' failed to be converted."
5                     redirect "/"
4                 end
3             else
4                 flash[:danger] = "'#{h params[:file][:filename]}' failed to be converted."
4                 redirect "/"
3             end
2         else
3             file = params["file"]
3             type = file[:type]
3             # Fingerprint file for mime-type if we aren't provided with it.
3             if type=="application/octet-stream"
4                 type = MIME::Types.type_for(file[:tempfile].path).first.content_type
3             end
3             blob = WSFile.create(name: file[:filename], content_type: type, edit_time: DateTime.now, create_time: DateTime.now)
3             blob.data = file[:tempfile].read
3             perm = Permission.create(user: current_user, file: blob, level: "owner")
3             flash[:success] = "'#{h file[:filename]}' was successfully uploaded."
3             redirect "/"
2         end
1     end
1     # This doesn't need to verify authentication because the token is a 16 byte string.
1     get '/:doc/download/:id' do
2         doc_id, doc = document_auth
2         response = $redis.get "websync:document_export:#{ params[:doc].decode62}:#{params[:id]}"
2         if response
3             ext = $redis.get "websync:document_export:#{ params[:doc].decode62}:#{params[:id]}:extension"
3             attachment(doc.name+'.'+ext)
3             content_type 'application/octet_stream'
3             response
2         else
3             halt 404
2         end
1     end
1     get '/:doc/json' do
2         doc_id, doc = document_auth
2         content_type 'application/json'
2         MultiJson.dump(doc.body)
1     end
1     get '/:doc/delete' do
2         doc_id, doc = document_auth
2         if doc.permissions(level: "owner").user[0]==current_user
3             doc.update(deleted: true)
3             flash[:danger] = "Document moved to trash."
2         else
3             halt 403
2         end
2         redirect '/'
1     end
1     get '/:doc/undelete' do
2         doc_id, doc = document_auth
2         if doc.permissions(level: "owner").user[0]==current_user
3             doc.update(deleted: false)
3             flash[:success] = "Document restored."
2         else
3             halt 403
2         end
2         redirect '/'
1     end
1     get '/:doc/destroy' do
2         doc_id, doc = document_auth
2         if doc.permissions(level: "owner").user[0]==current_user
3             erb :destroy, locals: {doc: doc}
2         else
3             halt 403
2         end
1     end
1     post '/:doc/destroy' do
2         doc_id, doc = document_auth
2         if doc.permissions(level: "owner").user[0]==current_user
3             if current_user.password == params[:password]
4                 doc.destroy_cascade
4                 flash[:danger] = "Document erased."
4                 redirect '/'
3             else
4                 flash.now[:danger] = "<strong>Error!</strong> Incorrect password."
4                 erb :destroy, locals: {doc: doc}
3             end
2         else
3             halt 403
2         end
1     end
1     get // do
2         parts = request.path_info.split("/")
2         pass unless parts.length >=3
2         doc = parts[1]
2         op = parts[2]
2         halt 400 unless ["edit","view", "assets"].include? parts[2]
2         if op == "upload"
3             redirect "/#{doc}/edit"
2         end
2         doc_id, doc = document_auth doc
2         if parts[2] == "assets"
3             if parts.length > 3
4                 cache do
5                     file = URI.unescape(parts[3..-1].join("/"))
5                     asset = doc.children(name: file)[0]
5                     if asset
6                         content_type asset.content_type
6                         response.write asset.data
6                         return
5                     else
6                         halt 404
5                     end
4                 end
3             else
4                 halt 404
3             end
2         end
2         @javascripts = [
3             #'/assets/bundle-edit.js'
2         ]
2         client_id = $redis.incr("clientid")
2         client_key = SecureRandom.uuid
2         user = doc.permissions(user: current_user)[0]
2         access = user.level if user
2         access ||= doc.default_level
2         $redis.set "websocket:id:#{client_id}",current_user.email
2         $redis.set "websocket:key:#{client_id}", client_key+":#{doc_id}"
2         $redis.expire "websocket:id:#{client_id}", 60*60*24*7
2         $redis.expire "websocket:key:#{client_id}", 60*60*24*7
2         erb :edit, locals:{no_bundle_norm: true, doc: doc, no_menu: true, edit: true, client_id: client_id, client_key: client_key, op: op, access: access, allow_iframe: true}
1     end
1     post "/:doc/upload" do
2         doc_id, doc = document_auth
2         editor! doc
2         files = []
2         if params.has_key? "files"
3             files = params["files"]
2         elsif params.has_key? "file"
3             files.push params["file"]
2         end
2         files.each do |file|
3             type = file[:type]
3             # Fingerprint file for mime-type if we aren't provided with it.
3             if type=="application/octet-stream"
4                 type = MIME::Types.type_for(file[:tempfile].path).first.content_type
3             end
3             ws_file = doc.children(name: file[:filename])[0]
3             if ws_file
4                 ws_file.update edit_time: DateTime.now
4                 ws_file.data = file[:tempfile].read
3             else
4                 blob = WSFile.create(parent: doc, name: file[:filename], content_type: type, edit_time: DateTime.now, create_time: DateTime.now)
4                 blob.data = file[:tempfile].read
3             end
3             $redis.del "url:/#{doc_id.encode62}/assets/#{URI.encode(file[:filename])}"
3             redirect "/#{doc_id.encode62}/edit"
2         end
2         if request.xhr?
3             content_type  "application/json"
3             return "{}"
2         end
1     end
0 end