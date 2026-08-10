import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void showToast(BuildContext context, String message, {bool isError = false}) {
  toastification.show(
    context: context,
    type: isError ? ToastificationType.error : ToastificationType.success,
    style: ToastificationStyle.flatColored,
    title: Text(isError ? 'Oops!' : 'Success'),
    description: Text(message),
    alignment: Alignment.topRight,
    autoCloseDuration: const Duration(seconds: 4),
    boxShadow: lowModeShadow,
    showProgressBar: true,
  );
}
