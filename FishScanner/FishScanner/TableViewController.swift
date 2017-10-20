//
//  TableViewController.swift
//  AquaristicInfo
//
//  Created by Németh Bendegúz on 2017. 03. 24..
//  Copyright © 2017. Németh Bendegúz. All rights reserved.
//

import UIKit

class TableViewController: UIViewController, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fishSpecies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FishCell", for: indexPath)
        
        cell.textLabel?.text = fishSpecies[indexPath.row]
        
        return cell
    }
    
    let fishSpecies = [
        "apteronotus albifrons",
        "betta splendens",
        "carnegiella strigata",
        "celestichthys margaritatus",
        "chromobotia macracanthus",
        "corydoras aeneus",
        "corydoras duplicareus",
        "corydoras paleatus",
        "crossocheilus oblongus",
        "ctenopoma acutirostre",
        "goldfish",
        "gymnocorymbus ternetzi",
        "hoplosternum thoracatum",
        "hyphessobrycon amandae",
        "hyphessobrycon herbertaxelrodi",
        "hyphessobrycon megalopterus",
        "hyphessobrycon pulchripinnis",
        "labeo bicolor",
        "labidochromis caeruleus",
        "melanochromis cyaneorhabdos",
        "melanotaenia boesemani",
        "mikrogeophagus ramirezi",
        "neolamprologus buescheri kamakonde",
        "osteoglossum bicirrhosum",
        "paracheirodon axelrodi",
        "paracheirodon innesi",
        "pethia conchonius",
        "petitella georgiae",
        "poecilia sphenops",
        "puntigrus tetrazona",
        "rocio octofasciata",
        "synodontis petricola",
        "tanichthys albonubes",
        "tropheus ikola",
        "xiphophorus helleri"]
}
