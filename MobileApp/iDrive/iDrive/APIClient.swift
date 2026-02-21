import Foundation

// Simple API client for the Ride State Backend.
// Uses a configurable baseURL (default localhost) and provides simple methods used by ViewModels.
// API client singleton declared below.

extension Notification.Name {
    static let apiUnauthorized = Notification.Name("apiUnauthorized")
}

final class APIClient {
    static let shared = APIClient()
    var baseURL: URL

    private init(base: String = "http://<HOST_IP>:3000") {
        self.baseURL = URL(string: base)!
    }

    func setBaseURL(_ urlString: String) {
        if let u = URL(string: urlString) { baseURL = u }
    }

    // MARK: - Auth
    func login(driverId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/login")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["driverId": driverId]
        do {
            req.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error)); return
        }
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let urlErr = err as? URLError, urlErr.code == .timedOut {
                    completion(.failure(NSError(domain: "API", code: urlErr.errorCode, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
                } else {
                    completion(.failure(err))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                if let obj = try? JSONDecoder().decode([String: String].self, from: data), let token = obj["token"] {
                    completion(.success(token))
                } else {
                    completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response (status \(http.statusCode))"])))
                }
            } else {
                // try to parse server error message
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    // MARK: - Rides
    func getRides(status: String? = nil, token: String, completion: @escaping (Result<[Ride], Error>) -> Void) {
        var components = URLComponents(url: baseURL.appendingPathComponent("/rides"), resolvingAgainstBaseURL: false)!
        if let s = status { components.queryItems = [URLQueryItem(name: "status", value: s)] }
        var req = URLRequest(url: components.url!)
        req.timeoutInterval = 30
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let urlErr = err as? URLError, urlErr.code == .timedOut {
                    completion(.failure(NSError(domain: "API", code: urlErr.errorCode, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
                } else {
                    completion(.failure(err))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                do {
                    let rides = try JSONDecoder().decode([Ride].self, from: data)
                    completion(.success(rides))
                } catch {
                    completion(.failure(error))
                }
            } else {
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    func getAllRides(token: String, completion: @escaping (Result<[Ride], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/__all_rides")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let urlErr = err as? URLError, urlErr.code == .timedOut {
                    completion(.failure(NSError(domain: "API", code: urlErr.errorCode, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
                } else {
                    completion(.failure(err))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                do {
                    let rides = try JSONDecoder().decode([Ride].self, from: data)
                    completion(.success(rides))
                } catch {
                    completion(.failure(error))
                }
            } else {
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    func getRide(rideId: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/rides/\(rideId)")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let urlErr = err as? URLError, urlErr.code == .timedOut {
                    completion(.failure(NSError(domain: "API", code: urlErr.errorCode, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
                } else {
                    completion(.failure(err))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                do {
                    let ride = try JSONDecoder().decode(Ride.self, from: data)
                    completion(.success(ride))
                } catch {
                    completion(.failure(error))
                }
            } else {
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    func createRide(payload: [String: Any], completion: @escaping (Result<Ride, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/rides")
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(.failure(error)); return
        }
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                if let urlErr = err as? URLError, urlErr.code == .timedOut {
                    completion(.failure(NSError(domain: "API", code: urlErr.errorCode, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])))
                } else {
                    completion(.failure(err))
                }
                return
            }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                do {
                    let ride = try JSONDecoder().decode(Ride.self, from: data)
                    completion(.success(ride))
                } catch {
                    completion(.failure(error))
                }
            } else {
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    private func sendSimpleRequest(path: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let http = resp as? HTTPURLResponse else { completion(.failure(NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response"]))); return }
            guard let data = data else { completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Empty response (status \(http.statusCode))"]))); return }
            if (200..<300).contains(http.statusCode) {
                do {
                    let ride = try JSONDecoder().decode(Ride.self, from: data)
                    completion(.success(ride))
                } catch {
                    completion(.failure(error))
                }
            } else {
                var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let em = obj["error"] as? String {
                    msg = em
                }
                completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Status \(http.statusCode): \(msg)"])))
            }
        }.resume()
    }

    func acceptRide(rideId: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        sendSimpleRequest(path: "/rides/\(rideId)/accept", token: token, completion: completion)
    }
    func startRide(rideId: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        sendSimpleRequest(path: "/rides/\(rideId)/start", token: token, completion: completion)
    }
    func completeRide(rideId: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        sendSimpleRequest(path: "/rides/\(rideId)/complete", token: token, completion: completion)
    }
    func cancelRide(rideId: String, token: String, completion: @escaping (Result<Ride, Error>) -> Void) {
        sendSimpleRequest(path: "/rides/\(rideId)/cancel", token: token, completion: completion)
    }

    func postLocation(rideId: String, lat: Double, lng: Double, token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/rides/\(rideId)/location")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["lat": lat, "lng": lng, "ts": Int(Date().timeIntervalSince1970 * 1000)]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error)); return
        }
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            if let http = resp as? HTTPURLResponse {
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
                    completion(.failure(NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                    return
                }
                if http.statusCode == 409 {
                    completion(.failure(NSError(domain: "API", code: 409, userInfo: [NSLocalizedDescriptionKey: "Conflict"])))
                    return
                }
                if http.statusCode >= 500 {
                    completion(.failure(NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                    return
                }
            }
            completion(.success(()))
        }.resume()
    }
}

