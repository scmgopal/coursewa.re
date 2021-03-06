require 'spec_helper'

describe Coursewareable::ClassroomsController do
  include ActionDispatch::TestProcess

  let(:classroom) { Fabricate('coursewareable/classroom') }
  let(:collaboration) {
    Fabricate('coursewareable/collaboration', :classroom => classroom) }
  let(:collaborator) { collaboration.user }

  describe 'GET dashboard' do
    context 'http request' do
      before do
        @controller.send(:auto_login, collaborator)
        @request.host = "#{classroom.slug}.#{@request.host}"
        get(:dashboard, :use_route => :coursewareable)
      end

      context 'being logged in as collaborator' do
        it { should render_template(:dashboard) }
      end
    end

    context 'xhr request' do
      before do
        @controller.send(:auto_login, collaborator)
        @request.host = "#{classroom.slug}.#{@request.host}"
        xhr(:get, :dashboard, :use_route => :coursewareable)
      end

      context 'being logged in as collaborator' do
        it { should render_template(:timeline) }
      end
    end
  end

  describe 'GET new' do
    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      get(:new, :use_route => :coursewareable)
    end

    context 'being logged in as collaborator' do
      it { should render_template(:new) }

      context 'with plan allowed classrooms limits reached' do
        before(:all) { collaborator.plan.decrement!(:allowed_classrooms, 100) }
        it { should redirect_to(login_path) }
      end
    end
  end

  describe 'GET staff' do
    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      get(:staff, :use_route => :coursewareable)
    end

    context 'being logged in as collaborator' do
      it { should render_template(:staff) }
    end
  end

  describe 'GET staff' do
    let(:format) { :html }
    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      get(:stats, :use_route => :coursewareable, :format => format)
    end

    context 'being logged in as owner' do
      it { should render_template(:stats) }

      context 'format is json' do
        let(:format) { :json }

        it 'renders all activities as JSON' do
          data = JSON.parse(response.body)
          data.count.should eq(classroom.all_activities.count)
          data.first.keys.count.should eq(2)
        end
      end
    end

  end

  describe 'POST :create' do
    let(:attrs) { Fabricate.build('coursewareable/classroom') }

    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      post(:create, :use_route => :coursewareable, :classroom => {
        :title => attrs.title, :description => attrs.description
      })
    end

    context 'being logged in as collaborator' do
      it { should redirect_to(classroom_url(
        :subdomain => collaborator.created_classrooms.last.slug))
      }

      context 'with plan allowed classrooms limits reached' do
        before(:all) { collaborator.plan.decrement!(:allowed_classrooms, 100) }
        it { should redirect_to(login_path) }
      end
    end
  end

  describe 'GET edit' do
    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      get(:edit, :use_route => :coursewareable)
    end

    context 'being logged in as collaborator' do
      it { should redirect_to(login_path) }
    end
  end

  describe 'PUT update' do
    let(:attrs) { Fabricate.build('coursewareable/classroom') }
    let(:members) { '' }
    let(:collabs) { '' }

    before do
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      put(:update, :use_route => :coursewareable, :classroom => {
        :title => attrs.title, :description => attrs.description,
        :slug => attrs.slug, :header_image => attrs.header_image
      }, :members => members, :collaborators => collabs)
    end

    context 'being logged in as collaborator' do
      before { classroom.reload }

      it { should redirect_to(login_path) }

      context 'with a valid new header image' do
        before(:all) do
          attrs.header_image = fixture_file_upload('/test.png', 'image/png')
        end

        it { classroom.reload.header_image.should be_nil }
      end

      context 'adds a new member' do
        let(:members) { Fabricate(:confirmed_user).id }

        it { classroom.member_ids.should_not include(members) }
      end

      context 'adds a new collaborator' do
        let(:collabs) { Fabricate(:confirmed_user).id }

        it { classroom.collaborator_ids.should_not include(collabs) }
      end
    end
  end

  describe 'POST announce' do
    let(:attrs) { Fabricate.build('coursewareable/classroom') }

    before do
      AnnouncementMailer.stub(:delay).and_return(AnnouncementMailer)
      AnnouncementMailer.should_receive(:new_announcement_email)
      @controller.send(:auto_login, collaborator)
      @request.host = "#{classroom.slug}.#{@request.host}"
      post(:announce, :use_route => :coursewareable,
           :announcement => attrs.description)
    end

    context 'being logged in as collaborator' do
      it { should redirect_to(dashboard_classroom_path) }
      it { classroom.all_activities.first.key.should eq('announcement.create')}
      it { classroom.all_activities.first.parameters[:content].should(
        eq(attrs.description)) }
    end
  end

end
