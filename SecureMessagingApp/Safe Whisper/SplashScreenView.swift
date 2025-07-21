//
//  SplashScreenView.swift
//  Safe Whisper
//
//  Created by Vasco Sousa on 21/07/2025.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isLoading = true
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var mottoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.5, blue: 0.92),
                    Color(red: 0.46, green: 0.29, blue: 0.64)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo
                SafeWhisperLogo()
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .delay(0.3),
                        value: logoScale
                    )
                    .animation(
                        .easeInOut(duration: 1.0)
                        .delay(0.5),
                        value: logoOpacity
                    )
                
                VStack(spacing: 8) {
                    // App name
                    Text("Safe Whisper")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Motto
                    VStack(spacing: 4) {
                        Text("Private. Encrypted.")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Yours.")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .opacity(mottoOpacity)
                .animation(
                    .easeInOut(duration: 1.0)
                    .delay(1.2),
                    value: mottoOpacity
                )
            }
            
            // Loading indicator
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .padding(.bottom, 80)
            }
            .opacity(isLoading ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: isLoading)
        }
        .onAppear {
            // Start animations
            logoScale = 1.0
            logoOpacity = 1.0
            mottoOpacity = 1.0
            
            // Hide loading after 3 seconds (simulate app startup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isLoading = false
            }
        }
    }
}

struct SafeWhisperLogo: View {
    var body: some View {
        ZStack {
            // Outer glow circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
            
            // Main lock shape
            VStack(spacing: 0) {
                // Lock shackle
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white, lineWidth: 6)
                    .frame(width: 50, height: 50)
                    .clipped()
                    .mask(
                        VStack {
                            Rectangle()
                                .frame(height: 30)
                            Spacer()
                        }
                    )
                
                // Lock body
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 70, height: 55)
                    .overlay(
                        // Keyhole
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.92))
                                .frame(width: 12, height: 12)
                            
                            Rectangle()
                                .fill(Color(red: 0.4, green: 0.5, blue: 0.92))
                                .frame(width: 4, height: 12)
                        }
                    )
            }
            .offset(y: -5)
            
            // Sound waves (whisper effect)
            HStack(spacing: 8) {
                Spacer()
                
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: CGFloat(8 + index * 4))
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: mottoOpacity
                            )
                    }
                }
                .offset(x: 40, y: -5)
            }
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    SplashScreenView()
}