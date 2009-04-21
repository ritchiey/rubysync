class ChangeTracksController < ApplicationController
  # GET /change_tracks
  # GET /change_tracks.xml
  def index
    @change_tracks = ChangeTrack.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @change_tracks }
    end
  end

  # GET /change_tracks/1
  # GET /change_tracks/1.xml
  def show
    @change_track = ChangeTrack.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @change_track }
    end
  end

  # GET /change_tracks/new
  # GET /change_tracks/new.xml
  def new
    @change_track = ChangeTrack.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @change_track }
    end
  end

  # GET /change_tracks/1/edit
  def edit
    @change_track = ChangeTrack.find(params[:id])
  end

  # POST /change_tracks
  # POST /change_tracks.xml
  def create
    @change_track = ChangeTrack.new(params[:change_track])

    respond_to do |format|
      if @change_track.save
        flash[:notice] = 'ChangeTrack was successfully created.'
        format.html { redirect_to(@change_track) }
        format.xml  { render :xml => @change_track, :status => :created, :location => @change_track }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @change_track.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /change_tracks/1
  # PUT /change_tracks/1.xml
  def update
    @change_track = ChangeTrack.find(params[:id])

    respond_to do |format|
      if @change_track.update_attributes(params[:change_track])
        flash[:notice] = 'ChangeTrack was successfully updated.'
        format.html { redirect_to(@change_track) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @change_track.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /change_tracks/1
  # DELETE /change_tracks/1.xml
  def destroy
    @change_track = ChangeTrack.find(params[:id])
    @change_track.destroy

    respond_to do |format|
      format.html { redirect_to(change_tracks_url) }
      format.xml  { head :ok }
    end
  end
end
