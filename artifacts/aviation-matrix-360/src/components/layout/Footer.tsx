import { Link } from "wouter";
import { PlaneTakeoff } from "lucide-react";

export function Footer() {
  return (
    <footer className="bg-primary text-primary-foreground pt-16 pb-8">
      <div className="container mx-auto px-4 md:px-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 mb-12">
          <div className="col-span-1 md:col-span-2">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <PlaneTakeoff className="h-8 w-8 text-secondary" />
              <span className="font-bold text-2xl tracking-tight text-white">
                Aviation Matrix 360
              </span>
            </Link>
            <p className="text-primary-foreground/80 max-w-md mt-4 leading-relaxed">
              Aviation Matrix 360 is an aviation ecosystem focused on operations, education, and future aviation learning.
            </p>
          </div>

          <div>
            <h4 className="font-bold text-lg mb-4 text-white">Navigation</h4>
            <ul className="space-y-3">
              <li>
                <Link href="/" className="text-primary-foreground/80 hover:text-white transition-colors">
                  Home
                </Link>
              </li>
              <li>
                <Link href="/about" className="text-primary-foreground/80 hover:text-white transition-colors">
                  About
                </Link>
              </li>
              <li>
                <Link href="/platform" className="text-primary-foreground/80 hover:text-white transition-colors">
                  Platform
                </Link>
              </li>
              <li>
                <Link href="/academy" className="text-primary-foreground/80 hover:text-white transition-colors">
                  Academy
                </Link>
              </li>
              <li>
                <Link href="/academy#kids" className="text-primary-foreground/80 hover:text-white transition-colors">
                  Kids Aviation Matrix
                </Link>
              </li>
              <li>
                <Link href="/contact" className="text-primary-foreground/80 hover:text-white transition-colors">
                  Contact
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="pt-8 border-t border-primary-foreground/10 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-sm text-primary-foreground/60">
            &copy; {new Date().getFullYear()} Aviation Matrix 360. All rights reserved.
          </p>
          <div className="flex gap-6 text-sm text-primary-foreground/60">
            <a href="#" className="hover:text-white transition-colors">Privacy Policy</a>
            <a href="#" className="hover:text-white transition-colors">Terms of Service</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
