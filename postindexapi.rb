require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/respond_to'
require 'yajl/json_gem'
Sinatra::Application.register Sinatra::RespondTo
use Rack::GoogleAnalytics, tracker: 'UA-35766527-2' if settings.environment == :production
set :haml, :format => :html5
set :public_folder, File.dirname(__FILE__) + '/static'
set :database_file, 'config/database.yml'

class PostIndex < ActiveRecord::Base
  self.primary_key = 'index'
  default_scope -> { order(:index) }
  has_many :subordinates, class_name: 'PostIndex', foreign_key: 'ops_subm'#, inverse_of: :superior
  belongs_to :superior, class_name: 'PostIndex' #, inverse_of: :subordinates
  def to_s; "#{self.index} — #{self.ops_name}" end
end

get %r{/(\d{6})} do |index|
  @index = PostIndex.where(index: index).first
  @index = PostIndex.where(index_old: index).order(:index).first unless @index
  raise Sinatra::NotFound unless @index
  last_modified @index.act_date
  respond_to do |format|
    format.html { haml :post_index }
    format.json {
      headers \
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'GET'
      yajl :post_index, callback: params[:callback]
    }
  end
end

get '/' do
  haml :dashboard
end

not_found do
  haml "%h1 Ничего не найдено\n%p Возможно вы опечатались в адресе…"
end

# Browsing part

get '/:region' do
  stub = PostIndex.where(region: params[:region])
  @cities   = stub.where(autonom: '', area: '').where.not(city: '').reorder(:city).uniq.pluck(:city)
  @areas    = stub.where(autonom: '').where.not(area: '').reorder(:area).uniq.pluck(:area)
  @autonoms = stub.where(area: '').where.not(autonom: '').reorder(:autonom).uniq.pluck(:autonom)
  @indices = PostIndex.where(region: params[:region], autonom: '', area: '', city: '')
  raise Sinatra::NotFound unless @cities.any? or @areas.any? or @autonoms.any? or @indices.any?
  haml :region
end

get '/:region/:city' do
  @indices = PostIndex.where(region: params[:region], city: params[:city])
  pass unless @indices.any?
  haml :city
end

get '/:region/:area' do
  @cities = PostIndex.where(region: params[:region], area: params[:area]).reorder(:city).uniq.pluck(:city)
  pass unless @cities.any?
  haml :area
end

get '/:region/:autonom' do
  @cities = PostIndex.where(region: params[:region], autonom: params[:autonom], area: '').reorder(:city).uniq.pluck(:city)
  @areas  = PostIndex.where(region: params[:region], autonom: params[:autonom]).reorder(:area).uniq.pluck(:area).reject{|a| a.blank?}
  raise Sinatra::NotFound unless @cities.any?
  haml :autonom
end


get '/:region/:area/:city' do
  @indices = PostIndex.where(region: params[:region], area: params[:area], city: params[:city])
  pass unless @indices.any?
  haml :city
end

get '/:region/:autonom/:city' do
  @indices = PostIndex.where(region: params[:region], autonom: params[:autonom], city: params[:city])
  pass unless @indices.any?
  haml :city
end

get '/:region/:autonom/:area' do
  indices = PostIndex.where(region: params[:region], autonom: params[:autonom], area: params[:area])
  @cities = indices.reorder(:city).uniq.pluck(:city)
  raise Sinatra::NotFound unless @cities.any?
  haml :area
end

get '/:region/:autonom/:area/:city' do
  puts params.reject{|k,v| ![:region,:autonom,:area,:city].include?(k)}
  @indices = PostIndex.where(region: params[:region], autonom: params[:autonom], area: params[:area], city: params[:city])
  raise Sinatra::NotFound unless @indices.any?
  haml :city
end

helpers do
  def breadcrumbs
    parts = []
    request.path_info.scan(/\//) do |c|
      offset = $~.offset(0)[0]
      parts << request.path_info[0..(offset)-1] unless offset.zero?
    end
    str = parts.map{|p| "<a href='#{to(p)}'>#{URI.unescape(p.split('/').last)}</a>"}.join(' / ')
    root_link = request.path_info == '/' ? '' : "<a href='#{to('/')}'>Начало</a>"
    bary = [root_link, str, URI.unescape(request.path_info.split('/').last||'')]
    bary.reject {|s| s.blank? }.flatten.join(' / ')
  end
end