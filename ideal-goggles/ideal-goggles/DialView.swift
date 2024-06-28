//
//  DialView.swift
//  ideal-goggles
//
//  Created by m1_air on 6/16/24.
//

import SwiftUI
import SwiftData
import MapKit
import UserNotifications
import WeatherKit

struct DialView: View {
    @Query var allNotifs: [NotificationData]
    @Environment(\.modelContext) var modelContext
    @State private var notificationViewModel: NotificationView = NotificationView()
    @State private var weatherManager = WeatherManager()
    @State private var locationManager = LocationManager()
    @State var screenWidth: Double = 0.0;
    @State var screenHeight: Double = 0.0;
    @State var dialValue: CGFloat = 0.0;
    @State var notifSheetList: Bool = false
    @State var toggleC: Bool = false;
    @State var statusColor: Color = .gray.opacity(0.8)
    @State var location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let calendar = Calendar.current
   
    var body: some View {
        GeometryReader { geometry in
            VStack {
                    //Weather Forecast
                    VStack(spacing: 12) {
                                Spacer().padding()
                                //Current Weather
                                CurrentView(weather: $weatherManager.weather, celsius: $notificationViewModel.notif.celcius, address: $notificationViewModel.notif.address)
                                Spacer()
                                //Hourly Weather
                                HourlyView(forecast: $weatherManager.hourlyForecast, celsius: $notificationViewModel.notif.celcius)
                            }
                            .onAppear {
                                getWeather()
                                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                                    if success {
                                        print("All set!")
                                    } else if let error {
                                        print(error.localizedDescription)
                                    }
                                }
                            }
                    //Celsius or Fahrenheit
                    Toggle(isOn:
                            $notificationViewModel.notif.celcius
                           , label: {
                        notificationViewModel.notif.celcius ? Text("Celsius") : Text("Fahrenheit")
                    }).tint(.black)
                    //Temperature Selection Dial
                    ZStack {
                            Background(isPressed: false, shape: Circle()).frame(width: 300, height: 300)
                            GlowTile_Circular(ringColor: statusColor)
                                Dial(dialValue: $dialValue, celsius: $notificationViewModel.notif.celcius).onChange(of: dialValue, {
                                    dialColor()
                            })
                            Button(action: {
                                let temp = weatherManager.hourlyForecast.first(where: {
                                    Int($0.temperature.converted(to: .fahrenheit).value) == Int((dialValue * 120)/100) && $0.date > Date.now
                                })
                                //timezone returned in GMT!!!!!
                                print("\(String(describing: temp?.date)) \(Int((((temp?.temperature.converted(to: .fahrenheit).value ?? 0.0)))))")
                                print(String(describing: temp?.date.timeIntervalSinceNow))
                                let content = UNMutableNotificationContent()
                                content.title = "Feed the cat"
                                content.subtitle = "It looks hungry"
                                content.sound = UNNotificationSound.default
                                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: temp?.date.timeIntervalSinceNow ?? 0.0, repeats: false) //needs a user facing indicator for this time!!!
                                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                                UNUserNotificationCenter.current().add(request)
                                let save = NotificationData(id: UUID().uuidString, name: "", temp: dialValue, long: notificationViewModel.notif.long, lat: notificationViewModel.notif.lat, address: notificationViewModel.notif.address, celcius: notificationViewModel.notif.celcius, active: true, alert: false)
                                modelContext.insert(save)
                            }, label: {
                                Image(systemName: "plus.circle.fill").tint(.white)
                            }).padding(EdgeInsets(top: 115, leading: 0, bottom: 0, trailing: 0))
                        }.padding()
                    //Notification List
                    Button(action: {
                        notifSheetList = true
                    }, label: {
                        Image(systemName: "list.bullet").tint(.black)
                    }).buttonStyle(NeumorphicButton(shape: RoundedRectangle(cornerRadius: 10)))
                    .sheet(isPresented: $notifSheetList, content: {
                        VStack{
                            Button(action: {
                                notifSheetList = false
                            }, label: {
                                Image(systemName: "chevron.down").tint(.black)
                                    .padding()
                            })
                            ScrollView {
                                ForEach(allNotifs) { notif in
                                    VStack(alignment: .leading) {
                                        GroupBox(content: {
                                            HStack{
                                                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
                                                    notif.active ?
                                                    Image(systemName: "bell.badge.fill").tint(.black) :
                                                    Image(systemName: "bell.slash.fill").tint(.gray)
                                                })
                                                Text(notif.address).fontWeight(.ultraLight)
                                                Spacer()
                                            }
                                        }, label: {
                                            HStack{
                                                notif.celcius ?
                                                Text("Notify at \((notif.temp * 120)/100, specifier: "%.0f")° C") :
                                                Text("Notify at \((notif.temp * 120)/100, specifier: "%.0f")° F")
                                                Spacer()
                                                Button(action: {
                                                    modelContext.delete(notif)
                                                }, label: {
                                                    Image(systemName: "minus").tint(.black)
                                                })
                                                }
                                            })
                                        }.padding()
                                    }
                                }
                            }
                        })
                
            }
        }.onAppear {
            screenWidth = UIScreen.main.bounds.size.width
            screenHeight = UIScreen.main.bounds.size.height
        }
        .NeumorphicStyle()
        .ignoresSafeArea()
    
    }
    
    func getWeather() {
        let location = locationManager.requestLocation()
        Task {
            notificationViewModel.notif.lat = location.coordinate.latitude
            notificationViewModel.notif.long = location.coordinate.longitude
            notificationViewModel.reverseGeocoding()
            await weatherManager.getWeather(lat: notificationViewModel.notif.lat,
                                            long: notificationViewModel.notif.long)
        }
    }
    
    func dialColor() {
        let selected = (dialValue * 120)/100
        if (selected > 0 && selected <= 37) {
            statusColor = Color.blue.opacity(0.8)
        } else if (selected > 37 && selected <= 72) {
            statusColor = Color.green.opacity(0.8)
        } else if (selected > 72 && selected <= 85) {
            statusColor = Color.orange.opacity(0.8)
        } else if (selected > 85 && selected <= 120) {
            statusColor = Color.red.opacity(0.8)
        }
    }
    
}

#Preview {
    DialView()
}
