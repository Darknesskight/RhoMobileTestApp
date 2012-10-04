require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'

class SettingsController < Rho::RhoController
  include BrowserHelper
  $loginName;
  def index
    @msg = @params['msg']
    render
  end

  def do_name
    File.open("current.txt" , "r") do |f1|
      return f1.gets
    end
    return $loginName
  end
  def add_interest
    if @params['interest']
      File.open(do_name + "\interests.txt" , "a") do |f1|
                f1.write(@params['interest'] + "\n")
    end
      render :action => :index
        end
    
  end
  def do_interests
    returnValue = ""
    temp = ""
    File.open(do_name + "\interests.txt", "r") do |line|
      while(temp = line.gets)
        returnValue += "<li><class=\"ui-li-icon\">" + temp + "</li>"
      end
     
    end
    return returnValue
  end
  def login
    @msg = @params['msg']
    render :action => :login
  end

  def login_callback
    errCode = @params['error_code'].to_i
    if errCode == 0
      # run sync if we were successful
      WebView.navigate Rho::RhoConfig.options_path
      SyncEngine.dosync
    else
      if errCode == Rho::RhoError::ERR_CUSTOMSYNCSERVER
        @msg = @params['error_message']
      end
        
      if !@msg || @msg.length == 0   
        @msg = Rho::RhoError.new(errCode).message
      end
      
      WebView.navigate ( url_for :action => :login, :query => {:msg => @msg} )
    end  
  end

  
  def do_register
      if @params['username'] and @params['password'] and @params['passwordverify']
        begin
          if Dir.glob(@params['username'] + ".txt").empty?
            begin
              if(not( @params['passwordverify'] == @params['password']))
                begin
                  @msg = "Password did not math"
                  render :action => :register 
                end
              else
                File.open(@params['username'] + ".txt" , "w") do |f1|
                  begin
                    f1.write(@params['password'])
                  end
                  Dir::mkdir(@params['username']) unless File.exists?(@params['username'])
                    begin
                      
                    end
                  end
                  File.open(@params['username'] + "\interests.txt" , "w") do |f1|
                  begin
                           f1.write("Mingle\n");
                  end
                  @msg = "You have made a new account. Please Login"
                  render :action => :login
                end
              end
            end
          else
            @msg = "Username already exists, Chose a different one"
            render :action => :register 
          end
        end
      else
        @msg = Rho::RhoError.err_message(Rho::RhoError::ERR_UNATHORIZED) unless @msg && @msg.length > 0
        render :action => :login
      end
    end
  
  def do_login
    if @params['login'] and @params['password']
      begin
        if Dir.glob(@params['login'] + ".txt").empty?
          begin
            @msg = "Username or password is incorrect"
            render :action => :login
          end
        else
          File.open(@params['login'] + ".txt" , "r") do |f1|
            if(f1.gets  == @params['password'])
              begin
                loginName = @params['login']
                File.open("current.txt" , "w") do |f2|
                  f2.truncate(0)
                  f2.write(@params['login'])
                end
              @msg = "Welcome Back " + loginName
              render :action => :index
            end
            else
              @msg = "Username or password is incorrect"
              render :action => :login
              end
          end
         
            
        end
      end
    else
      @msg = Rho::RhoError.err_message(Rho::RhoError::ERR_UNATHORIZED) unless @msg && @msg.length > 0
      render :action => :login
    end
  end
  
  def logout
    @msg = "You have been logged out."
    render :action => :login
  end
  
  def reset
    render :action => :reset
  end
  
  def do_reset
    Rhom::Rhom.database_full_reset
    SyncEngine.dosync
    @msg = "Database has been reset."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def do_sync
    SyncEngine.dosync
    @msg =  "Sync has been triggered."
    redirect :action => :index, :query => {:msg => @msg}
  end
  
  def sync_notify
  	status = @params['status'] ? @params['status'] : ""
  	
  	# un-comment to show a debug status pop-up
  	#Alert.show_status( "Status", "#{@params['source_name']} : #{status}", Rho::RhoMessages.get_message('hide'))
  	
  	if status == "in_progress" 	
  	  # do nothing
  	elsif status == "complete"
      WebView.navigate Rho::RhoConfig.start_path if @params['sync_type'] != 'bulk'
  	elsif status == "error"
	
      if @params['server_errors'] && @params['server_errors']['create-error']
        SyncEngine.on_sync_create_error( 
          @params['source_name'], @params['server_errors']['create-error'].keys, :delete )
      end

      if @params['server_errors'] && @params['server_errors']['update-error']
        SyncEngine.on_sync_update_error(
          @params['source_name'], @params['server_errors']['update-error'], :retry )
      end
      
      err_code = @params['error_code'].to_i
      rho_error = Rho::RhoError.new(err_code)
      
      @msg = @params['error_message'] if err_code == Rho::RhoError::ERR_CUSTOMSYNCSERVER
      @msg = rho_error.message unless @msg && @msg.length > 0   

      if rho_error.unknown_client?( @params['error_message'] )
        Rhom::Rhom.database_client_reset
        SyncEngine.dosync
      elsif err_code == Rho::RhoError::ERR_UNATHORIZED
        WebView.navigate( 
          url_for :action => :login, 
          :query => {:msg => "Server credentials are expired"} )                
      elsif err_code != Rho::RhoError::ERR_CUSTOMSYNCSERVER
        WebView.navigate( url_for :action => :err_sync, :query => { :msg => @msg } )
      end    
	end
  end  
end
