class Helpdesk < Sinatra::Base
  #List all uoms
  get '/stores-list' do
    self.init_ctx
    #check if role is admin
    if !self.is_user_logged_in() || @rolename != 'admin'
      redirect '/'
      return #Does execution stop with a redirect, or do we need a return in this framework?
    end

    @skip = 0
    if @skip != nil && @skip != ''
      @skip = @params[:skip].to_i
    end

    @criteria = {}
    if (@params[:code] != nil && @params[:code] != '') then @criteria[:code] = {  '$regex' => '.*' + Regexp.escape(@params[:code]) + '.*', '$options' => 'i' } end
    if (@params[:name] != nil && @params[:name] != '') then @criteria[:name] = {  '$regex' => '.*' + Regexp.escape(@params[:name]) + '.*', '$options' => 'i' } end
    if (@params[:description] != nil && @params[:description] != '') then @criteria[:description] = {  '$regex' => '.*' + Regexp.escape(@params[:description]) + '.*', '$options' => 'i' } end

    @totalrowcount = 0
    @totalrowcount = @list = @db[:stores].find(@criteria).count()
    @list = @db[:stores].find(@criteria).skip(@skip).limit(@pagesize)

    @showpager = true

    erb :storeslist
  end

  #Create a user account
  post '/store-save' do
    self.init_ctx
    #check if role is admin before saving
    if !self.is_user_logged_in() || @rolename != 'admin'
      redirect '/'
      return #Does execution stop with a redirect, or do we need a return in this framework?
    end

    if @params[:code] != 'nil' && @params[:code].downcase == 'new'
      redirect '/store-list?msg=Cannot use NEW as UOM code'
      return
    end
    @params[:code] = @params[:code].upcase

    cnt = @db[:stores].find('code' => @params[:code]).count()
    if cnt == 0
      recstore = {
          :code => @params[:code],
          :name => @params[:name],
          :description=> @params[:description]
      }

      @db[:stores].insert_one recstore
    elsif cnt == 1
      recstore = @db[:stores].find('code' => @params[:code]).limit(1).first
      recstore[:name] = @params[:name]
      recstore[:description] = @params[:description]

      @db[:stores].update_one(
          {'code' => @params[:code]},
          recstore,
          {:upsert => false}
      )
    else
      #TODO: Toss a warning
    end

    @db.close
    redirect '/stores-list?msg=Saved'
  end

  #remove part and quantity
  post '/store-part-remove/:code' do
    part_code = @params['part_code']

    @rec = @db[:stores].find('code' => @params[:code]).limit(1).first

    #TODO: Replace this drama queen of a code with a simple count check if we aren't using any of the record fields when posting
    if @rec == nil
      redirect '/store-detail/'+@params[:code]
      #redirect '/'
      return #Is a return absolutely necessary?
    end

    @rec[:parts].delete(@rec[:parts].find { |x| x[:part_code] == part_code } )

    @db[:stores].update_one(
        {'code' => @params[:code]},
        @rec,
        {:upsert => false}
    )

    redirect '/store-detail/' + URI.encode_www_form_component(@params[:code]) + '?msg=Part+deleted'
  end

  #add part and quantity
  post '/store-part/:code' do
    part_code = @params['part_code']

    self.init_ctx
    if !self.is_user_logged_in()
      redirect '/login'
      return
    end


      @rec = @db[:stores].find('code' => @params[:code]).limit(1).first

    #TODO: Replace this drama queen of a code with a simple count check if we aren't using any of the record fields when posting
    if @rec == nil
      redirect '/'
      return #Is a return absolutely necessary?
    end

    check_existing = @rec[:parts] == nil ? nil : @rec[:parts].find { |x| x[:part_code] == part_code }
    if check_existing
      @rec[:parts].delete(@rec[:parts].find { |x| x[:part_code] == part_code } )

      @db[:stores].update_one(
          {'code' => @params[:code]},
          @rec,
          {:upsert => false}
      )
    end

    part_for_ticket = { :part_code => @params[:part_code], :uom => @params[:uom], :qty => @params[:qty] }

    @db[:stores].update_one(
        {'code' => @params[:code] },
        {'$push' => {'parts' => part_for_ticket }},
        {:upsert => false}
    )

    @db.close

   redirect '/store-detail/' + URI.encode_www_form_component(@params[:code]) + '?msg=Part+saved'

  end

  #Get info about a single user
  get '/store-detail/:code' do
    self.init_ctx
    if !self.is_user_logged_in()
      redirect '/login'
      return
    end

    if @rolename != 'admin'
      redirect '/'
      return
    end

    @params[:code] = URI.decode_www_form_component @params[:code]

    @rec = @db[:stores].find('code' => @params[:code]).limit(1).first

    @parts = @db[:parts].find()

    erb :storedetail
  end

end