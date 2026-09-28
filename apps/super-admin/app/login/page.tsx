import { Suspense } from 'react';
import LoginForm from './LoginForm';

export default function LoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center text-white/50">Loading...</div>}>
      <LoginForm />
    </Suspense>
  );
}
