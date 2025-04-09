//  Project: Waypoint
//  Course: CS371L
//
//  ChallengeInfo.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/3/25.
//

// custom class to hold information for each challenge
class ChallengeInfo{
    var type: String!
    var description: String!
    var id: Int!
    var points: Int!
    
    init(data: [String: Any]) {
        self.type = data["type"] as? String
        self.description = data["description"] as? String
        self.id = data["id"] as? Int
        self.points = data["points"] as? Int
    }
}
