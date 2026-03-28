import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class ChatRoomScreen extends StatelessWidget {
	const ChatRoomScreen({
		super.key,
		required this.currentUserId,
		required this.partnerId,
		required this.partnerName,
		this.partnerAvatarUrl,
	});

	final String currentUserId;
	final String partnerId;
	final String partnerName;
	final String? partnerAvatarUrl;

	@override
	Widget build(BuildContext context) {
		final String subtitle = 'Sẵn sàng bắt đầu cuộc trò chuyện với $partnerName';

		return Scaffold(
			appBar: AppBar(
				title: Text(partnerName),
				backgroundColor: Colors.white,
				foregroundColor: AppColors.lightText,
				elevation: 0,
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						colors: <Color>[Color(0xFFF9F6FF), Color(0xFFFFFFFF)],
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
					),
				),
				child: SafeArea(
					child: Padding(
						padding: const EdgeInsets.all(20),
						child: Column(
							children: <Widget>[
								const SizedBox(height: 24),
								CircleAvatar(
									radius: 44,
									backgroundColor: AppColors.lavender,
									backgroundImage: partnerAvatarUrl?.trim().isNotEmpty == true
											? NetworkImage(partnerAvatarUrl!)
											: null,
									child: partnerAvatarUrl?.trim().isNotEmpty == true
											? null
											: const Icon(
													Icons.person,
													color: AppColors.deepPurple,
													size: 36,
												),
								),
								const SizedBox(height: 20),
								Text(
									partnerName,
									style: const TextStyle(
										fontSize: 24,
										fontWeight: FontWeight.w700,
										color: AppColors.lightText,
									),
								),
								const SizedBox(height: 8),
								Text(
									subtitle,
									textAlign: TextAlign.center,
									style: const TextStyle(
										fontSize: 14,
										color: AppColors.lightTextSecondary,
										height: 1.4,
									),
								),
								const SizedBox(height: 20),
								Container(
									padding: const EdgeInsets.all(18),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(24),
										border: Border.all(color: AppColors.lavender),
										boxShadow: [
											BoxShadow(
												color: Colors.black.withValues(alpha: 0.05),
												blurRadius: 24,
												offset: const Offset(0, 12),
											),
										],
									),
									child: const Column(
										children: <Widget>[
											Icon(
												Icons.chat_bubble_outline,
												color: AppColors.deepPurple,
												size: 36,
											),
											SizedBox(height: 12),
											Text(
												'Màn hình Chat Room đã sẵn sàng.',
												textAlign: TextAlign.center,
												style: TextStyle(
													fontSize: 16,
													fontWeight: FontWeight.w600,
													color: AppColors.lightText,
												),
											),
											SizedBox(height: 8),
											Text(
												'Bạn có thể nối tiếp phần backend chat sau khi hoàn thiện luồng nhắn tin.',
												textAlign: TextAlign.center,
												style: TextStyle(
													fontSize: 13,
													color: AppColors.lightTextSecondary,
													height: 1.4,
												),
											),
										],
									),
								),
								const Spacer(),
								SizedBox(
									width: double.infinity,
									height: 52,
									child: ElevatedButton(
										onPressed: () {},
										style: ElevatedButton.styleFrom(
											backgroundColor: AppColors.deepPurple,
											foregroundColor: Colors.white,
											shape: RoundedRectangleBorder(
												borderRadius: BorderRadius.circular(18),
											),
											elevation: 0,
										),
										child: const Text(
											'Nhắn tin',
											style: TextStyle(
												fontSize: 15,
												fontWeight: FontWeight.w700,
											),
										),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}