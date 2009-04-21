require 'test_helper'

class ChangeTracksControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:change_tracks)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create change_track" do
    assert_difference('ChangeTrack.count') do
      post :create, :change_track => { }
    end

    assert_redirected_to change_track_path(assigns(:change_track))
  end

  test "should show change_track" do
    get :show, :id => change_tracks(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => change_tracks(:one).to_param
    assert_response :success
  end

  test "should update change_track" do
    put :update, :id => change_tracks(:one).to_param, :change_track => { }
    assert_redirected_to change_track_path(assigns(:change_track))
  end

  test "should destroy change_track" do
    assert_difference('ChangeTrack.count', -1) do
      delete :destroy, :id => change_tracks(:one).to_param
    end

    assert_redirected_to change_tracks_path
  end
end
