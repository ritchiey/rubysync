class AssociationTracksController < ApplicationController
  # GET /association_tracks
  # GET /association_tracks.xml
  def index
    @association_tracks = AssociationTrack.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @association_tracks }
    end
  end

  # GET /association_tracks/1
  # GET /association_tracks/1.xml
  def show
    @association_track = AssociationTrack.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @association_track }
    end
  end

  # GET /association_tracks/new
  # GET /association_tracks/new.xml
  def new
    @association_track = AssociationTrack.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @association_track }
    end
  end

  # GET /association_tracks/1/edit
  def edit
    @association_track = AssociationTrack.find(params[:id])
  end

  # POST /association_tracks
  # POST /association_tracks.xml
  def create
    @association_track = AssociationTrack.new(params[:association_track])

    respond_to do |format|
      if @association_track.save
        flash[:notice] = 'AssociationTrack was successfully created.'
        format.html { redirect_to(@association_track) }
        format.xml  { render :xml => @association_track, :status => :created, :location => @association_track }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @association_track.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /association_tracks/1
  # PUT /association_tracks/1.xml
  def update
    @association_track = AssociationTrack.find(params[:id])

    respond_to do |format|
      if @association_track.update_attributes(params[:association_track])
        flash[:notice] = 'AssociationTrack was successfully updated.'
        format.html { redirect_to(@association_track) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @association_track.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /association_tracks/1
  # DELETE /association_tracks/1.xml
  def destroy
    @association_track = AssociationTrack.find(params[:id])
    @association_track.destroy

    respond_to do |format|
      format.html { redirect_to(association_tracks_url) }
      format.xml  { head :ok }
    end
  end
end
