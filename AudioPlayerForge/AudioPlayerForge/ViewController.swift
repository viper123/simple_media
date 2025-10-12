import UIKit
import AVFoundation

class AudioPlayerViewController: UIViewController {
    
    // MARK: - UI Elements
    private let trackArtImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "music.note")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let trackTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Track Title"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let totalTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0.3
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let player = AudioPlayer()
    
    let samplePlaylist = [
                AudioItem(
                    id: "1",
                    uri: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!,
                    artUri: URL(string: "https://picsum.photos/id/237/200/300")!,
                    title: "Sample Track 1",
                    album: "Sample Album",
                    extra: nil,
                    uriHeaders: nil,
                    artHeaders: nil
                ),
                AudioItem(
                    id: "2",
                    uri: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3")!,
                    artUri: URL(string: "https://picsum.photos/id/237/200/300")!,
                    title: "Sample Track 2",
                    album: "Sample Album",
                    extra: nil,
                    uriHeaders: nil,
                    artHeaders: nil
                )
            ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Log.installLogger(DefaultiOSLogger())
        
        setupUI()
        setupTargets()
        setupPlayerListeners()
        
        _ = player.loadPlaylist(samplePlaylist)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Audio Player"
        
        // Add all subviews
        view.addSubview(trackArtImageView)
        view.addSubview(trackTitleLabel)
        view.addSubview(currentTimeLabel)
        view.addSubview(totalTimeLabel)
        view.addSubview(progressSlider)
        view.addSubview(previousButton)
        view.addSubview(playPauseButton)
        view.addSubview(stopButton)
        view.addSubview(nextButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Track art image
            trackArtImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            trackArtImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trackArtImageView.widthAnchor.constraint(equalToConstant: 200),
            trackArtImageView.heightAnchor.constraint(equalToConstant: 200),
            
            // Track title
            trackTitleLabel.topAnchor.constraint(equalTo: trackArtImageView.bottomAnchor, constant: 20),
            trackTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trackTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Current time label
            currentTimeLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 60),
            currentTimeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // Total time label
            totalTimeLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 60),
            totalTimeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            totalTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // Progress slider
            progressSlider.centerYAnchor.constraint(equalTo: currentTimeLabel.centerYAnchor),
            progressSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 10),
            progressSlider.trailingAnchor.constraint(equalTo: totalTimeLabel.leadingAnchor, constant: -10),
            
            // Control buttons - distributed evenly across screen width
            previousButton.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 60),
            previousButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            previousButton.widthAnchor.constraint(equalToConstant: 50),
            previousButton.heightAnchor.constraint(equalToConstant: 50),
            
            playPauseButton.centerYAnchor.constraint(equalTo: previousButton.centerYAnchor),
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -35),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            playPauseButton.heightAnchor.constraint(equalToConstant: 60),
            
            stopButton.centerYAnchor.constraint(equalTo: previousButton.centerYAnchor),
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 35),
            stopButton.widthAnchor.constraint(equalToConstant: 50),
            stopButton.heightAnchor.constraint(equalToConstant: 50),
            
            nextButton.centerYAnchor.constraint(equalTo: previousButton.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: 50),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupTargets() {
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        previousButton.addTarget(self, action: #selector(previousButtonTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        progressSlider.addTarget(self, action: #selector(progressSliderChanged), for: .valueChanged)
    }
    
    private func setupPlayerListeners() {
        player.setDurationListener { [weak self] duration in
            self?.totalTimeLabel.text = duration.toMMSSString()
        }
        
        player.setPlaybackProgressListener{ [weak self] progress, duration in
            self?.currentTimeLabel.text = progress.toMMSSString()
        }
        
        player.setActiveIndexListener { activeIndex in
            print("Active index changed to: \(activeIndex)")
        }
        
        player.setPlaybackStateListener {[weak self] state in
            print("Player state changed to \(state)")
            switch state {
            case .playing:
                self?.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            case .paused:
                self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            case .idle:
                self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            case .loading:
                break
            case .seeking:
                break
            case .error:
                self?.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            }
        }
        
        player.setUpdateMetadataListener { [weak self] metadata, image in
            self?.trackArtImageView.image = image
            self?.trackTitleLabel.text = metadata.title
        }
        
        player.setErrorListener { code, msg in
            print("Error ocurred: \(code), \(String(describing: msg))")
        }
    }
    
    // MARK: - Button Actions (UI Only)
    @objc private func playPauseButtonTapped() {
        // Toggle play/pause button icon
        let currentImage = playPauseButton.image(for: .normal)
        let playImage = UIImage(systemName: "play.fill")
        let pauseImage = UIImage(systemName: "pause.fill")
        
        if currentImage == playImage {
            player.play()
            playPauseButton.setImage(pauseImage, for: .normal)
        } else {
            player.pause()
            playPauseButton.setImage(playImage, for: .normal)
        }
        
        print("Play/Pause button tapped")
    }
    
    @objc private func stopButtonTapped() {
        // Reset to play icon and slider to beginning
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        progressSlider.value = 0
        currentTimeLabel.text = "00:00"
        
        print("Stop button tapped")
        player.stop()
    }
    
    @objc private func previousButtonTapped() {
        // Visual feedback - you can add track switching logic here later
        print("Previous button tapped")
        player.moveBackward()
    }
    
    @objc private func nextButtonTapped() {
        // Visual feedback - you can add track switching logic here later
        print("Next button tapped")
        player.moveForward()
    }
    
    @objc private func progressSliderChanged() {
        // Update current time label based on slider position
        let sliderValue = progressSlider.value
        guard let duration = player.duration else { return }
        let totalMs = duration.seconds * 1000
        
        let newProgressMs = Int(totalMs * Double(sliderValue))
        
        let time : CMTime = CMTime(value: CMTimeValue(newProgressMs), timescale: 1000)
        
        player.seek(at: time)
        
        print("Progress slider changed to: \(time.seconds) ")
    }
}
