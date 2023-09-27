//
//  ImageViewerViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 24.02.2023.
//

import UIKit
import SDWebImage
import JGProgressHUD

//show image from conversations
class ImageViewerViewController: UIViewController {
    
    let url : URL
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hidesBottomBarWhenPushed = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down.fill"), style: .done, target: self, action: #selector(saveToPhotoGallery))
        view.backgroundColor = .black
        view.addSubview(imageView)
        imageView.sd_setImage(with: url)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
    }
    
    @objc func imageSavingError(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            let indicator = JGProgressHUD(style: .light)
            indicator.indicatorView = JGProgressHUDErrorIndicatorView()
            indicator.textLabel.text = "Error saving the image..."
            indicator.show(in: view, animated: true)
            indicator.dismiss(afterDelay: 2, animated: true)
        } else {
            let indicator = JGProgressHUD(style: .light)
            indicator.indicatorView = JGProgressHUDSuccessIndicatorView()
            indicator.textLabel.text = "Image saved succesfully!"
            indicator.show(in: view, animated: true)
            indicator.dismiss(afterDelay: 2, animated: true)
        }
    }
    
    @objc func saveToPhotoGallery() {
        let alert = UIAlertController(title: "Save image to your Photo Library?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save image", style: .default, handler: { action in
            guard let image = self.imageView.image else {
                return
            }
            //save photo to gallery
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.imageSavingError(_:didFinishSavingWithError:contextInfo:)), nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    
}

