//
//  DiscoverTableViewController.swift
//  FoodPin
//
//  Created by Anton Novoselov on 11/12/2016.
//  Copyright © 2016 AppCoda. All rights reserved.
//

import UIKit
import CloudKit

class DiscoverTableViewController: UITableViewController {

    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    var restaurants:[CKRecord] = []
    
    var imageCache = NSCache<CKRecordID, NSURL>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Pull to refresh control
        
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.white
        refreshControl?.tintColor = UIColor.gray
        refreshControl?.addTarget(self, action: #selector(fetchRecordsFromCloud), for: .valueChanged)
        
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        parent!.view.addSubview(spinner)
        spinner.startAnimating()

        fetchRecordsFromCloud()
        
    }
    // ===TOUSE===
    // Operational API
    func fetchRecordsFromCloud() {
        
        // Remove existing records before fetching
        self.restaurants.removeAll()
        self.tableView.reloadData()
        
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Restaurant", predicate: predicate)
        
        let createAtSortDescriptor = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [createAtSortDescriptor]
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.desiredKeys = ["name", "type", "location"]
        queryOperation.queuePriority = .veryHigh
        queryOperation.resultsLimit = 50
        
        queryOperation.recordFetchedBlock = { record in
            self.restaurants.append(record)
        }
        
        queryOperation.queryCompletionBlock = { cursor, error in
            
            if let error = error {
                print(error.localizedDescription)
                
            } else {
                print("===NAG=== Successfully retrieve the data from iCloud")
                
                OperationQueue.main.addOperation {
                    self.spinner.stopAnimating()
                    self.tableView.reloadData()
                    
                    if let refreshControl = self.refreshControl {
                        if refreshControl.isRefreshing {
                            refreshControl.endRefreshing()
                        }
                    }
                }
            }
        }
        
        publicDatabase.add(queryOperation)
        
    }
    
    
    // Convenience API
    /*
    func fetchRecordsFromCloud() {
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Restaurant", predicate: predicate)
        
        publicDatabase.perform(query, inZoneWith: nil, completionHandler: { results, error in
            
            if error != nil {
                print(error!.localizedDescription)
            }
            if let results = results {
                print("===NAG=== Downloaded Restaurants from iCloud")
                self.restaurants = results
                
                OperationQueue.main.addOperation {
                    
                    self.tableView.reloadData()
                }
            }
        })
    }
    */
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return restaurants.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! RestaurantTableViewCell
        
        let restaurant = restaurants[indexPath.row]
        
        cell.nameLabel.text = restaurant.object(forKey: "name") as? String
        cell.typeLabel.text = restaurant.object(forKey: "type") as? String
        cell.locationLabel.text = restaurant.object(forKey: "location") as? String

        
        // Set the default image
        cell.thumbnailImageView.image = UIImage(named: "photoalbum")
        
        
        // CACHE: Check if the image is stored in cache
        if let imageFileURL = imageCache.object(forKey: restaurant.recordID) {
            
            print("===NAG=== Get image from cache")
            
            if let imageData = try? Data(contentsOf: imageFileURL as URL) {
                cell.thumbnailImageView.image = UIImage(data: imageData)
            }
            
        } else {
            // CACHE: No cache found - Fetch the image from iCloud in background
            let publicDatabase = CKContainer.default().publicCloudDatabase
            let fetchRecordsImageOperation = CKFetchRecordsOperation(recordIDs: [restaurant.recordID])
            fetchRecordsImageOperation.desiredKeys = ["image"]
            fetchRecordsImageOperation.queuePriority = .veryHigh
            
            fetchRecordsImageOperation.perRecordCompletionBlock = { record, recordID, error in
                
                if let error = error {
                    print("===NAG=== Error to get restaurant image: \(error.localizedDescription)")
                } else {
                    if let restaurantRecord = record {
                        OperationQueue.main.addOperation {
                            if let image = restaurantRecord.object(forKey: "image") {
                                let imageAsset = image as! CKAsset
                                if let imageData = try? Data(contentsOf: imageAsset.fileURL) {
                                    cell.thumbnailImageView.image = UIImage(data: imageData)
                                }
                                
                                // Add the image URL to cache
                                self.imageCache.setObject(imageAsset.fileURL as NSURL, forKey: restaurant.recordID)
                            }
                        }
                    }
                }
            }
            
            publicDatabase.add(fetchRecordsImageOperation)
            
        }
     

        // Way withoud placeholders (need to add "image" to queryOperation.desiredKeys in fetchRecordsFromCloud() method)
        /*
        if let image = restaurant.object(forKey: "image") {
            let imageAsset = image as! CKAsset
            
            
            if let imageData = try? Data(contentsOf: imageAsset.fileURL) {
                cell.imageView?.image = UIImage(data: imageData)
            }
        }
        */
        
        return cell
    }
    
}













