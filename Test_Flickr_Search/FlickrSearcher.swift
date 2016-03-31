//
//  FlickrSearcher.swift
//  flickrSearch
//
//  Created by Richard Turton on 31/07/2014.
//  Copyright (c) 2014 Razeware. All rights reserved.
//

import UIKit
import Foundation
import Alamofire
import Sync
import DATAStack

struct FlickrSearchResults {
  let searchTerm : String
  let searchResults : [FlickrPhoto]
}

class FlickrPhoto : Equatable {
  var thumbnail : UIImage?
  var largeImage : UIImage?
  let photoID : String
  let farm : Int
  let server : String
  let secret : String
  
  init (photoID:String,farm:Int, server:String, secret:String) {
    self.photoID = photoID
    self.farm = farm
    self.server = server
    self.secret = secret
  }
  
    // change m to b
  func flickrImageURL(size:String = "b") -> NSURL {
    return NSURL(string: "http://farm\(farm).staticflickr.com/\(server)/\(photoID)_\(secret)_\(size).jpg")!
  }
  
  func loadLargeImage(completion: (flickrPhoto:FlickrPhoto, error: NSError?) -> Void) {
    let loadURL = flickrImageURL("b")
    let loadRequest = NSURLRequest(URL:loadURL)
    
    NSURLSession().dataTaskWithRequest(loadRequest) { (data, response, error) in
        if error == nil {
            if data != nil {
                let returnedImage = UIImage(data: data!)
                self.largeImage = returnedImage
                completion(flickrPhoto: self, error: nil)
                return
            }
        } else {
            completion(flickrPhoto: self, error: error)
            return
        }
    }
  }
  
  func sizeToFillWidthOfSize(size:CGSize) -> CGSize {
    if thumbnail == nil {
      return size
    }
    
    let imageSize = thumbnail!.size
    var returnSize = size
    
    let aspectRatio = imageSize.width / imageSize.height
    
    returnSize.height = returnSize.width / aspectRatio
    
    if returnSize.height > size.height {
      returnSize.height = size.height
      returnSize.width = size.height * aspectRatio
    }
    
    return returnSize
  }
  
}

func == (lhs: FlickrPhoto, rhs: FlickrPhoto) -> Bool {
  return lhs.photoID == rhs.photoID
}

class Flickr {
    
    // MARK: - var and let
    private static let apiKey = "a1df8f5c713b4afa7d44ca6d099d3da0"
    private let apiSecret = "845ccfea135687e6"
    private let processingQueue = NSOperationQueue()
    private let appDelegate = (UIApplication.sharedApplication().delegate as! AppDelegate)
    // MARK: - functions
  
    func searchFlickrForTerm(searchTerm: String, completion : (results: FlickrSearchResults?, error : NSError?) -> Void){
    
        let searchURL = flickrSearchURLForSearchTerm(searchTerm)
        let searchRequest = NSURLRequest(URL: searchURL)
        print(searchURL)
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        session.dataTaskWithRequest(searchRequest) { (data, response, error) in
            if error != nil {
                print(error?.localizedDescription)
                completion(results: nil,error: error)
                return
            }
        
            do {
                guard let resultsDictionary = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as? [String : AnyObject] else { return }
                switch (resultsDictionary["stat"] as! String) {
                    case "ok":
                        print("Results processed OK")
                    case "fail":
                        let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:resultsDictionary["message"]!])
                        completion(results: nil, error: APIError)
                    return
                default:
                    let APIError = NSError(domain: "FlickrSearch", code: 0, userInfo: [NSLocalizedFailureReasonErrorKey:"Uknown API response"])
                    completion(results: nil, error: APIError)
                    return
                }
            
                let photosContainer = resultsDictionary["photos"] as! [String : AnyObject]
                let photosReceived = photosContainer["photo"] as! [[String : AnyObject]]
            
                let flickrPhotos : [FlickrPhoto] = photosReceived.map {
                photoDictionary in
                
                let photoID = photoDictionary["id"] as? String ?? ""
                let farm = photoDictionary["farm"] as? Int ?? 0
                let server = photoDictionary["server"] as? String ?? ""
                let secret = photoDictionary["secret"] as? String ?? ""
                
                let flickrPhoto = FlickrPhoto(photoID: photoID, farm: farm, server: server, secret: secret)
                print(flickrPhoto.flickrImageURL())
                let imageData = NSData(contentsOfURL: flickrPhoto.flickrImageURL())
                flickrPhoto.thumbnail = UIImage(data: imageData!)
                
                return flickrPhoto
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                completion(results:FlickrSearchResults(searchTerm: searchTerm, searchResults: flickrPhotos), error: nil)
            })
            
        } catch let error as NSError {
            print(error.localizedDescription, error.userInfo)
            completion(results: nil, error: error)
            return
            }
        }.resume()
    }
  
  private func flickrSearchURLForSearchTerm(searchTerm: String) -> NSURL {
    let escapedTerm = searchTerm.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
//    let urlString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(escapedTerm)&per_page=20&format=json&nojsoncallback=1"
    
    let urlString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(Flickr.apiKey)&text=\(escapedTerm)&has_geo=1&geo_context=&per_page=20&format=json&nojsoncallback=1"
    return NSURL(string: urlString)!
  }
    
    static func flickrGetImageLocation(index: String, completion: ((CoordinateEntity) -> ())) {
        let urlString = "https://api.flickr.com/services/rest/?method=flickr.photos.geo.getLocation&api_key=\(apiKey)&photo_id=\(index)&format=json&nojsoncallback=1"
        Alamofire.request(.GET, urlString).responseJSON { (response) in
            let result = response.result
            if result.error == nil {
                if result.isSuccess {
                    guard let dictionary = result.value as? [String : AnyObject] else { return }
                    guard let photo = dictionary["photo"] as? [String : AnyObject] else { return }
                    guard let location = photo["location"] as? [String : AnyObject] else { return }
                    print(location)
                    guard let latitude = location["latitude"] as? String else { return }
                    guard let longitude = location["longitude"] as? String else { return }
                    let coordinateLocation = CoordinateEntity(latitude: Double(latitude)!, longitude: Double(longitude)!)
                    completion(coordinateLocation)
                } else {
                    print("result is Failure")
                }
            } else {
                print(result.error?.localizedDescription, result.error?.userInfo)
            }
        }
    }
    
    // MARK: - saving functions
    private func saveData(data: [[String : AnyObject]]) {
        let dataStack = appDelegate.dataStack
        Sync.changes(data, inEntityNamed: "PhotoEntity", dataStack: dataStack) { (error) in
            if error != nil {
                print(error?.localizedDescription, error?.userInfo)
            } else {
                print("Save is successful")
            }
        }
    }
}
