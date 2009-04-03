require 'test_helper'

class RubySyncAssociationsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:ruby_sync_associations)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create ruby_sync_association" do
    assert_difference('RubySyncAssociation.count') do
      post :create, :ruby_sync_association => { }
    end

    assert_redirected_to ruby_sync_association_path(assigns(:ruby_sync_association))
  end

  test "should show ruby_sync_association" do
    get :show, :id => ruby_sync_associations(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => ruby_sync_associations(:one).to_param
    assert_response :success
  end

  test "should update ruby_sync_association" do
    put :update, :id => ruby_sync_associations(:one).to_param, :ruby_sync_association => { }
    assert_redirected_to ruby_sync_association_path(assigns(:ruby_sync_association))
  end

  test "should destroy ruby_sync_association" do
    assert_difference('RubySyncAssociation.count', -1) do
      delete :destroy, :id => ruby_sync_associations(:one).to_param
    end

    assert_redirected_to ruby_sync_associations_path
  end
end
