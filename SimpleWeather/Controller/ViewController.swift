import UIKit
import Alamofire
import SVProgressHUD
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var citytextField: UITextField!
    @IBOutlet weak var cityLabel: UILabel!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var conditionLabel: UILabel!
    @IBOutlet weak var weatherIconImageView: UIImageView!
    
    // MARK: - Properties
    let locationManager = CLLocationManager()
    var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let key = config["API_KEY"] as? String else {
            return nil
        }
        return key
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        citytextField.textAlignment = .left
        cityLabel.alpha = 0.0
        tempLabel.alpha = 0.0
        conditionLabel.alpha = 0.0
        weatherIconImageView.alpha = 0.0
        
        citytextField.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization() // Request permissions
        
        // Dismiss keyboard on tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        UIView.animate(withDuration: 0.5) {
            self.cityLabel.alpha = 1.0
            self.tempLabel.alpha = 1.0
            self.conditionLabel.alpha = 1.0
            self.weatherIconImageView.alpha = 1.0
        }
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation() // Automatically fetch location when authorized
        case .denied, .restricted:
            showAlert(title: "Location Access Required",
                      message: "Please enable location services in Settings to use this feature.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            fetchWeatherByCoordinates(latitude: latitude, longitude: longitude)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        var errorMessage = "Unable to fetch location. Please check your location settings."
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location access was denied. Please enable it in Settings."
            case .locationUnknown:
                errorMessage = "The location could not be determined. Try again later."
            default:
                break
            }
        }
        
        showAlert(title: "Error", message: errorMessage)
    }

    // MARK: - Fetch Weather Data
    func fetchWeather(for city: String) {
        guard let apiKey = apiKey else {
            showAlert(title: "Error", message: "API Key is missing.")
            return
        }
        
        let url = "https://api.openweathermap.org/data/2.5/weather"
        let parameters: [String: String] = [
            "q": city,
            "appid": apiKey,
            "units": "metric"
        ]
        
        SVProgressHUD.show()
        
        AF.request(url, method: .get, parameters: parameters).responseJSON { response in
            SVProgressHUD.dismiss()
            
            switch response.result {
            case .success(let value):
                guard let data = value as? [String: Any] else {
                    self.showAlert(title: "Error", message: "Unexpected response format.")
                    return
                }
                
                if let code = data["cod"] as? Int, code == 200 {
                    self.updateUI(with: data)
                } else if let message = data["message"] as? String {
                    self.showAlert(title: "Error", message: message)
                }
                
            case .failure(let error):
                self.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    func fetchWeatherByCoordinates(latitude: Double, longitude: Double) {
        guard let apiKey = apiKey else {
            showAlert(title: "Error", message: "API Key is missing.")
            return
        }
        
        let url = "https://api.openweathermap.org/data/2.5/weather"
        let parameters: [String: String] = [
            "lat": "\(latitude)",
            "lon": "\(longitude)",
            "appid": apiKey,
            "units": "metric"
        ]
        
        SVProgressHUD.show()
        
        AF.request(url, method: .get, parameters: parameters).responseJSON { response in
            SVProgressHUD.dismiss()
            
            switch response.result {
            case .success(let value):
                if let data = value as? [String: Any] {
                    self.updateUI(with: data)
                }
            case .failure(let error):
                self.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Update UI
    func updateUI(with data: [String: Any]) {
        if let main = data["main"] as? [String: Any],
           let weatherArray = data["weather"] as? [[String: Any]],
           let weather = weatherArray.first {

            let temp = main["temp"] as? Double ?? 0.0
            let condition = weather["description"] as? String ?? "N/A"
            let city = data["name"] as? String ?? "Unknown"
            
            // Print weather condition for debugging
            print("Weather condition for \(city): \(condition)")

            // Set custom background image based on the weather condition
            setBackgroundImage(for: condition)

            // Set custom weather icon
            setCustomIcon(for: condition)
            
            DispatchQueue.main.async {
                self.cityLabel.text = city
                self.tempLabel.text = "\(Int(temp))°C"
                self.conditionLabel.text = condition.capitalized
            }
        }
    }

    // MARK: - Set Custom Background
    func setBackgroundImage(for condition: String) {
        var imageName: String

        switch condition.lowercased() {
        case "clear sky", "few clouds":
            imageName = "clear_sky_background"
        case "scattered clouds", "broken clouds", "mist":
            imageName = "cloudy_background"
        case "rain", "light rain", "moderate rain":
            imageName = "rainy_background"
        case "snow", "light snow", "moderate snow":
            imageName = "snowy_background"
        case "thunderstorm":
            imageName = "thunderstorm_background"
        default:
            imageName = "default_background"
        }

        DispatchQueue.main.async {
            self.view.layer.contents = UIImage(named: imageName)?.cgImage
        }
    }

    // MARK: - Set Custom Icon
    func setCustomIcon(for condition: String) {
        var imageName: String

        switch condition.lowercased() {
        case "clear sky":
            imageName = "sunny"
        case "few clouds", "scattered clouds", "broken clouds", "overcast clouds":
            imageName = "overcast"
        case "rain", "light rain", "moderate rain":
            imageName = "rainy"
        case "snow", "light snow", "moderate snow":
            imageName = "snowy"
        case "thunderstorm":
            imageName = "thunderstorm"
        case "mist", "cloudy":
            imageName = "cloudy"
        default:
            imageName = "custom_default"
        }

        DispatchQueue.main.async {
            self.weatherIconImageView.image = UIImage(named: imageName)
        }
    }

    // MARK: - Alerts
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Actions
    @IBAction func SearchBtnPressed(_ sender: UIButton) {
        guard let cityName = citytextField.text, !cityName.isEmpty else {
            showAlert(title: "Error", message: "Please enter a city name.")
            return
        }
        fetchWeather(for: cityName)
    }
    
    @IBAction func currentLctPressed(_ sender: UIButton) {
        let status = CLLocationManager.authorizationStatus()
        
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            showAlert(title: "Location Access Required",
                      message: "Please enable location services in Settings to use this feature.")
        } else {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField == citytextField {
            SearchBtnPressed(searchButton)
        }
        return true
    }
}
