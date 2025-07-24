//
// Created by Banghua Zhao on 24/07/2025
// Copyright Apps Bay Limited. All rights reserved.
//
  

import Foundation
import SharingGRDB

@Table
struct PromptCategory: Identifiable {
    let id: Int
    var title: String = ""
}

extension PromptCategory.Draft: Identifiable {}
