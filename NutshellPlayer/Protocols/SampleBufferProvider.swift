//
//  SampleBufferProvider.swift
//  NutshellPlayer
//
//  Created by Andy Zhang on 2026/2/25.
//

import CoreMedia

protocol SampleBufferProvider {
    func copyNextSampleBuffer() -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent>?
}
