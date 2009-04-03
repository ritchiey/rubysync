class RubySyncAssociationsController < ApplicationController
  # GET /ruby_sync_associations
  # GET /ruby_sync_associations.xml
  def index
    @ruby_sync_associations = RubySyncAssociation.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @ruby_sync_associations }
    end
  end

  # GET /ruby_sync_associations/1
  # GET /ruby_sync_associations/1.xml
  def show
    @ruby_sync_association = RubySyncAssociation.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @ruby_sync_association }
    end
  end

  # GET /ruby_sync_associations/new
  # GET /ruby_sync_associations/new.xml
  def new
    @ruby_sync_association = RubySyncAssociation.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @ruby_sync_association }
    end
  end

  # GET /ruby_sync_associations/1/edit
  def edit
    @ruby_sync_association = RubySyncAssociation.find(params[:id])
  end

  # POST /ruby_sync_associations
  # POST /ruby_sync_associations.xml
  def create
    @ruby_sync_association = RubySyncAssociation.new(params[:ruby_sync_association])

    respond_to do |format|
      if @ruby_sync_association.save
        flash[:notice] = 'RubySyncAssociation was successfully created.'
        format.html { redirect_to(@ruby_sync_association) }
        format.xml  { render :xml => @ruby_sync_association, :status => :created, :location => @ruby_sync_association }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @ruby_sync_association.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /ruby_sync_associations/1
  # PUT /ruby_sync_associations/1.xml
  def update
    @ruby_sync_association = RubySyncAssociation.find(params[:id])

    respond_to do |format|
      if @ruby_sync_association.update_attributes(params[:ruby_sync_association])
        flash[:notice] = 'RubySyncAssociation was successfully updated.'
        format.html { redirect_to(@ruby_sync_association) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @ruby_sync_association.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /ruby_sync_associations/1
  # DELETE /ruby_sync_associations/1.xml
  def destroy
    @ruby_sync_association = RubySyncAssociation.find(params[:id])
    @ruby_sync_association.destroy

    respond_to do |format|
      format.html { redirect_to(ruby_sync_associations_url) }
      format.xml  { head :ok }
    end
  end
end
