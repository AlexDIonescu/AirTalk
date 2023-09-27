//
//  StorageManager.swift
//  AirTalk
//
//  Created by Alex Ionescu on 12.02.2023.
//

import Foundation
import FirebaseStorage
import UIKit
import AVFoundation


final class StorageManager {
    
    // MARK: Singleton design pattern
    static let shared = StorageManager()
    
    //refference to Firebase Storage
    let storage = Storage.storage().reference()
    
    
    // MARK: upload profile picture to Firebase
    public func uploadProfilePhoto(data: Data, filename: String, completition: @escaping(Result<String, Error>) -> Void) {
        storage.child("profileImages/\(filename)").putData(data) { metadata, error in
            guard error == nil else {
                completition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("profileImages/\(filename)").downloadURL { url, error in
                
                guard let url = url else {
                    print("Cannot get the download url")
                    completition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print(urlString)
                completition(.success(urlString))
            }
        }
    }
    
    // MARK: photo messages
    public func uploadMessagePhoto(data: Data, filename: String, completition: @escaping(Result<String, Error>) -> Void) {
        storage.child("conversation_photos/\(filename)").putData(data) { metadata, error in
            guard error == nil else {
                completition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("conversation_photos/\(filename)").downloadURL { url, error in
                
                guard let url = url else {
                    print("Cannot get the download url")
                    completition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print(urlString)
                completition(.success(urlString))
            }
        }
    }
    
    
    // MARK: create image from video - placeholder for video messages
    func imageFromVideo(url: URL, completition: @escaping (UIImage?)-> Void) {
        var imagePlaceholder = UIImage()
        
        let avUrlAsset = AVURLAsset(url: url)
        let placeholderCreator = AVAssetImageGenerator(asset: avUrlAsset)
        placeholderCreator.appliesPreferredTrackTransform = true
        
        do{
            let img = try placeholderCreator.copyCGImage(at: .zero, actualTime: nil)
            imagePlaceholder = UIImage(cgImage: img)
            completition(imagePlaceholder)
        } catch {}
    }

    
    // MARK: upload video messages
    func uploadMessageVideo(url: URL, filename: String, completition: @escaping(Result<String, Error>) -> Void) {
        var data = Data()
        do {
            data = try Data(contentsOf: url)
        } catch {
            
        }
        storage.child("conversation_videos/\(filename)").putData(data){ metadata, error in
            guard error == nil else {
                
                completition(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("conversation_videos/\(filename)").downloadURL { url, error in
                
                guard let url = url else {
                    print("Cannot get the download url")
                    completition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print(urlString)
                completition(.success(urlString))
            }
        }
    }
    
    func uploadAudioMessage(url: URL, filename: String, completition: @escaping(Result<String, Error>) -> Void) {
        
        var data = Data()
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("Error uploading the audio file")
            completition(.failure(StorageErrors.failedToUpload))
        }
        
        storage.child("conversation_audios/\(filename)").putData(data){ metadata, error in
            guard error == nil else {
                
                completition(.failure(StorageErrors.failedToUpload))
                return
            }
            self.storage.child("conversation_audios/\(filename)").downloadURL { url, error in
                
                guard let url = url else {
                    completition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print(urlString)
                completition(.success(urlString))
            }
        }
    }
    
    // MARK: get download url for media
    public func downloadUrl(path: String, completition: @escaping(Result<URL, Error>) -> Void) {
        
        let storageRef = storage.child(path)
        
        storageRef.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completition(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            completition(.success(url))
        })
    }
    
    // MARK: storage errors
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadUrl
        
    }
}
