class HobbiesController < ApplicationController
  # GET /hobbies
  # GET /hobbies.xml
  def index
    @hobbies = Hobby.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @hobbies }
    end
  end

  # GET /hobbies/1
  # GET /hobbies/1.xml
  def show
    @hobby = Hobby.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @hobby }
    end
  end

  # GET /hobbies/new
  # GET /hobbies/new.xml
  def new
    @hobby = Hobby.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @hobby }
    end
  end

  # GET /hobbies/1/edit
  def edit
    @hobby = Hobby.find(params[:id])
  end

  # POST /hobbies
  # POST /hobbies.xml
  def create
    @hobby = Hobby.new(params[:hobby])

    respond_to do |format|
      if @hobby.save
        flash[:notice] = 'Hobby was successfully created.'
        format.html { redirect_to(@hobby) }
        format.xml  { render :xml => @hobby, :status => :created, :location => @hobby }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @hobby.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /hobbies/1
  # PUT /hobbies/1.xml
  def update
    @hobby = Hobby.find(params[:id])

    respond_to do |format|
      if @hobby.update_attributes(params[:hobby])
        flash[:notice] = 'Hobby was successfully updated.'
        format.html { redirect_to(@hobby) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @hobby.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /hobbies/1
  # DELETE /hobbies/1.xml
  def destroy
    @hobby = Hobby.find(params[:id])
    @hobby.destroy

    respond_to do |format|
      format.html { redirect_to(hobbies_url) }
      format.xml  { head :ok }
    end
  end
end
