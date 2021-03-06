# -*- coding: utf-8 -*-
require 'rubygems'
require 'sinatra'
require 'haml'
require 'date'
require 'nokogiri'
require 'open-uri'
require 'sequel'
require "sinatra/reloader" if development?

require './init'

#https://maps.google.fr/maps?saddr=14+Rue+de+Lorraine,+Asni%C3%A8res-sur-Seine&daddr=Ris-Orangis


## Helpers
helpers do
  def link_to text, url
    "<a href='#{ URI.encode url }'>#{ text }</a>"
  end
  #vérifie si la date est le matin ou le soir (après / avant 13h) => defaut = matin
  def is_morning?(myDate)
    if myDate.nil? or myDate == 0
        true
    else
        if DateTime.strptime(myDate, "%Y-%m-%d_%H-%M").hour < 13
            true
        else
            false
        end
    end
            
  end
end

get '/' do
  haml :index
end

# [ ]
#https://maps.google.fr/maps?saddr=14+Rue+de+Lorraine,+Asni%C3%A8res-sur-Seine&daddr=26+Rue+de+la+Rochefoucauld,+Boulogne-Billancourt

get '/run/:now' do
    if params[:now]
        Path.each do |path|
            begin
              is_morning = 1
              origin = URI::encode(path.origin)
              destination = URI::encode(path.destination)
              if !is_morning?(params[:now]) #Si c'est le soir, on inverse destination et origin
                  origin,destination = destination, origin
                  is_morning = 0
              end
              logger.info "https://maps.google.fr/maps?saddr=#{ origin }&daddr=#{ destination }"
              doc = Nokogiri::HTML(open("https://maps.google.fr/maps?saddr=#{ origin }&daddr=#{ destination }"))  
              data = doc.xpath("//*[@id='altroute_0']/div/div[2]/span")
              if data.length != 0 #il y a des bouchons
                data = data.text.split(":")[1].split(" ")
                #first result: "Dans les conditions actuelles de circulation : 1 heure 10 min" 
              elsif doc.xpath("//*[@id='altroute_0']/div/div[1]/span").length != 0 #pas de bouchon => pas le même code html
                data = doc.xpath("//*[@id='altroute_0']/div/div[1]/span[2]").text.split(" ")
              end #les autres cas tomberont en erreur => récupération via le rescue
              
              min = 0
              if data.length > 2 #more than 1 hour
                  min = data[0].to_i*60 + data[2].to_i
              else
                  min = data[0].to_i
              end
              logger.info "origin: #{origin} dest: #{destination} nb min:#{min.to_s}"
              Result.create(:date => DateTime.strptime(params[:now], "%Y-%m-%d_%H-%M"), :minutes => min, :path_id => path.id, :is_morning => is_morning)
            rescue Exception => e
              logger.error "/run/ :" + e.message
            end
        end
    end
    return "200"
end


 