# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arclight::RepositoriesController, type: :controller do
  routes { Arclight::Engine.routes }
  before do
    ENV['REPOSITORY_FILE'] = 'spec/fixtures/config/repositories.yml'
  end

  describe '#index' do
    it 'displays the repositories' do
      get :index
      expect(response).to be_success
    end

    it 'assigns the view variable' do
      get :index
      repos = controller.instance_variable_get(:@repositories)
      expect(repos).to be_an(Array)
      expect(repos.first).to be_an(Arclight::Repository)
      expect(repos.size).to eq 5
    end
  end

  describe '#show' do
    it 'looks up the repository detail page' do
      get :show, params: { id: 'nlm' }
      repo = controller.instance_variable_get(:@repository)
      expect(repo).to be_an(Arclight::Repository)
      expect(repo.slug).to eq 'nlm'
      collections = controller.instance_variable_get(:@collections)
      expect(collections.first).to be_an(SolrDocument)
      expect(collections.find { |c| c.id == 'aoa271' }.unitid).to eq 'MS C 271'
    end

    it 'raises RecordNotFound if non-registered slug' do
      expect { get :show, params: { id: 'not-registered' } }.to raise_error(
        ActiveRecord::RecordNotFound
      )
    end
  end
end
