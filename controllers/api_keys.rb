# API key management
# We sync with the central API key service to figure out which users are developers, based on email


# Verify that posts to API key management endpoints are verified

before /^\/services\// do
  unless SunlightServices.verify params, config[:services][:shared_secret], config[:services][:api_name]
    halt 403, 'Bad signature' 
  end
end



# API key management endpoints

post '/services/create_key/' do
  begin
    ApiKey.create! :key => params[:key],
        :email => params[:email],
        :status => params[:status]
  rescue
    halt 403, "Could not create key, duplicate key or email"
  end
end

post '/services/update_key/' do
  if key = ApiKey.where(:key => params[:key]).first
    begin
      key.attributes = {:email => params[:email], :status => params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate API key by the given key'
  end
end

post '/services/update_key_by_email/' do
  if key = ApiKey.where(:email => params[:email]).first
    begin
      key.attributes = {:key => params[:key], :status => params[:status]}
      key.save!
    rescue
      halt 403, "Could not update key, errors: #{key.errors.full_messages.join ', '}"
    end
  else
    halt 404, 'Could not locate API key by the given email'
  end
end


# store API keys in Mongo

class ApiKey
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :key
  field :email
  field :status
  
  validates_presence_of :key
  validates_presence_of :email
  validates_presence_of :status
  validates_uniqueness_of :key
  validates_uniqueness_of :email
  
  index :key
  index :email
  index :status
  
  def self.allowed?(key)
    !ApiKey.where(:key => key, :status => 'A').first.nil?
  end
end


# SunlightServices helper class

require 'cgi'
require 'hmac-sha1'
require 'net/http'

class SunlightServices
  
  def self.verify(params, shared_secret, api_name)
    return false unless params[:key] and params[:email] and params[:status]
    return false unless params[:api] == api_name
    
    given_signature = params.delete 'signature'
    signature = signature_for params, shared_secret
    
    signature == given_signature
  end

  def self.signature_for(params, shared_secret)
    HMAC::SHA1.hexdigest shared_secret, signature_string(params)
  end

  def self.signature_string(params)
    params.keys.map(&:to_s).sort.map do |key|
      "#{key}=#{CGI.escape((params[key] || params[key.to_sym]).to_s)}"
    end.join '&'
  end
end