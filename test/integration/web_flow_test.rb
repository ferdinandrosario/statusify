require 'test_helper'

class WebFlowTest < ActionDispatch::IntegrationTest
  test 'get index' do
    get '/'
    assert_response :success, 'Failed to get index page'
  end

  test 'sign in' do
    get '/users/sign_in'
    assert_response :success, 'Failed to get sign in page'
    # Checking with valid credentials
    sign_in(User.first.email, 'password')
    assert_equal flash[:notice], 'Signed in successfully.', 'Failed to log in in via valid credentials.'
    # Sign out
    delete '/users/sign_out'
    # Checking with invalid credentials
    sign_in(User.first.email, 'foobar')
    assert_equal 'Invalid email or password.', flash[:alert]
  end

  test 'create incident' do
    sign_in(User.first.email, 'password')
    get '/incidents/new'
    assert_response :success, 'Failed to get new incident page'
    # Create an incident same as the first one, provided by the fixtures
    r = create_incident(Incident.first, '/incidents')
    assert_equal 'success', r.headers['status'], 'Could not create valid incident'
    # Create an invalid incident
    r = create_incident(Incident.new(name: nil, component: nil), '/incidents')
    assert_equal 'failed', r.headers['status'], 'Could create invalid incident'
  end

  test 'modify incident' do
    sign_in(User.first.email, 'password')
    get "/incidents/#{Incident.first.id}/edit"
    assert_response :success, 'Could not get edit page'
    # Edit incident with valid parameters
    i = {name: 'Updated name', message: 'updated message', status: 'updated status', component: 'Updated component', severity: 'major'}
    r = edit_incident(i, "/incidents/#{Incident.first.id}/edit")
    assert_equal 'success', r.headers['status'], 'Could not edit valid incident'
    # Edit incident with invalid parameters
    i = {name: '', message: '', status: '', component: '', severity: ''}
    r = edit_incident(i, "/incidents/#{Incident.first.id}/edit")
    assert_equal 'failed', r.headers['status'], 'Could edit invalid incident'
  end

  test 'delete incident' do
    sign_in(User.first.email, 'password')
    # Delete valid incident
    r = delete_incident "/incidents/#{Incident.first.id}"
    assert_equal 'success', r.headers['status'], 'Could not delete invalid incident'
    # Delete invalid incident
    r = delete_incident "/incidents/#{(rand * 10_000).to_i}"
    assert_equal 'failed', r.headers['status'], 'Could delete invalid incident'
  end

  test 'deactivate incident' do
    sign_in(User.first.email, 'password')
    # Deactivate valid incident
    r = get "/incidents/#{Incident.first(2).last.id}/deactivate"
    assert_equal 'success', response.headers['status'], 'Unable to deactivate valid incident'
  end

  test 'view incident' do
    r = get "/incidents/#{Incident.first(2).last.id}"
    assert_equal nil, flash['warning']
    r = get "/incidents/#{(rand * 10_000).to_i}"
    assert_equal 'Unable to find that incident', flash['warning']
  end

  test 'status dot check' do
    sign_in('u@umangis.me', 'password')
    get '/status.svg'
    assert_redirected_to "#{Statusify.app_url}/down.svg", 'Redirected to unknown path, had active incidents.'
    # Deactivate all incidents.
    Incident.where(active: true).each do |m|
      m.user = User.first
      m.active = false
      m.save!
    end
    # Should redirect us to the 'up' SVG.
    get '/status.svg'
    assert_redirected_to "#{Statusify.app_url}/up.svg", 'Redirected to unknown path, had inactive incidents only.'
  end

  def sign_in(email, password)
    post_via_redirect '/users/sign_in', 'user[email]' => email, 'user[password]' => password
    response
  end

  def create_incident(i, path)
    # Path is where we send the POST request.
    return if i.class != Incident
    post path, 'incident[name]' => i.name, 'incident[events_attributes][0][message]' => 'Test Message', 'incident[component]' => i.component, 'incident[events_attributes][0][status]' => 'Test status', 'incident[severity]' => i.severity
    response
  end

  def edit_incident(i, path)
    # Path is where we send the PATCH request.
    patch path, 'incident[name]' => i[:name], 'incident[event][message]' => i[:message], 'incident[event][status]' => i[:status], 'incident[severity]' => i[:severity]
    response
  end

  def delete_incident(path)
    delete path
    response
  end
end
