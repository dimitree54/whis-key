import Foundation
import Alamofire


class AudioRecognitionService {
    let endpointUrl = "https://rashchenko.xyz:443/"
    lazy var recogniseUrl: String = {
        return self.endpointUrl + "recognise"
    }()
    lazy var editUrl: String = {
        return self.endpointUrl + "edit"
    }()
    
    func recognise(audioFilename: URL, smartMode: Bool, completion: @escaping (String?, Error?) -> Void) {
        let headers: HTTPHeaders = ["Content-type": "multipart/form-data"]
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(audioFilename, withName: "m4a_file")
            multipartFormData.append(Data("\(smartMode)".utf8), withName: "smart_mode")
        }, to: recogniseUrl, headers: headers)
        .responseDecodable(of: AudioRecognitionResponse.self) { response in
            switch response.result {
            case .success(let recognitionResponse):
                completion(recognitionResponse.transcript, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    func edit(audioFilename: URL, text2edit: String, completion: @escaping (String?, Error?) -> Void) {
        let headers: HTTPHeaders = ["Content-type": "multipart/form-data"]
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(audioFilename, withName: "m4a_file")
            multipartFormData.append(Data("\(text2edit)".utf8), withName: "text")
        }, to: editUrl, headers: headers)
        .responseDecodable(of: AudioRecognitionResponse.self) { response in
            switch response.result {
            case .success(let recognitionResponse):
                completion(recognitionResponse.transcript, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

struct AudioRecognitionResponse: Decodable {
    let transcript: String?
}
