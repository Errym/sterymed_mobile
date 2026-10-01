import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/error_message.dart';
import '../../data/repositories/auth_repository.dart';
import 'forgot_password_event.dart';
import 'forgot_password_state.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final AuthRepository _repository;

  ForgotPasswordBloc(this._repository) : super(const ForgotPasswordIdle()) {
    on<SubmitForgotPassword>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitForgotPassword event,
    Emitter<ForgotPasswordState> emit,
  ) async {
    emit(const ForgotPasswordLoading());
    try {
      await _repository.forgotPassword(email: event.email);
      emit(const ForgotPasswordSuccess());
    } on ApiException catch (e) {
      emit(ForgotPasswordFailure(ErrorMessage.from(e)));
    } catch (e) {
      emit(ForgotPasswordFailure(ErrorMessage.from(e)));
    }
  }
}
