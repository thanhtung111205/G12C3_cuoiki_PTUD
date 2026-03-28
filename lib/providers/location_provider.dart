import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider extends ChangeNotifier {
	Position? _currentPosition;
	bool _isLocationVisible = true;
	bool _isLoading = false;
	String? _errorMessage;

	Position? get currentPosition => _currentPosition;
	bool get isLocationVisible => _isLocationVisible;
	bool get isLoading => _isLoading;
	String? get errorMessage => _errorMessage;

	void updatePosition(Position position) {
		_currentPosition = position;
		notifyListeners();
	}

	void updateVisibility(bool isVisible) {
		_isLocationVisible = isVisible;
		notifyListeners();
	}

	void setLoading(bool value) {
		_isLoading = value;
		notifyListeners();
	}

	void setErrorMessage(String? message) {
		_errorMessage = message;
		notifyListeners();
	}

	void clear() {
		_currentPosition = null;
		_errorMessage = null;
		_isLoading = false;
		_isLocationVisible = true;
		notifyListeners();
	}
}