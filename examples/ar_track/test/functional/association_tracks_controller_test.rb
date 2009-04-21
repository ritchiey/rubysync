require 'test_helper'

class AssociationTracksControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:association_tracks)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create association_track" do
    assert_difference('AssociationTrack.count') do
      post :create, :association_track => { }
    end

    assert_redirected_to association_track_path(assigns(:association_track))
  end

  test "should show association_track" do
    get :show, :id => association_tracks(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => association_tracks(:one).to_param
    assert_response :success
  end

  test "should update association_track" do
    put :update, :id => association_tracks(:one).to_param, :association_track => { }
    assert_redirected_to association_track_path(assigns(:association_track))
  end

  test "should destroy association_track" do
    assert_difference('AssociationTrack.count', -1) do
      delete :destroy, :id => association_tracks(:one).to_param
    end

    assert_redirected_to association_tracks_path
  end
end
